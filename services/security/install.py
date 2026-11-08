#!/usr/bin/python3
"""Explicit, reviewed sudo deployment only. Never run this from a daemon."""
import argparse
import grp
import json
import os
from pathlib import Path
import plistlib
import pwd
import re
import shutil
import stat
import subprocess
import tempfile

BASE = Path('/usr/local/libexec/mac-server')
BIN = Path('/usr/local/bin')
REPO = Path(__file__).resolve().parents[2]
TOOLS = ('age', 'alloy', 'blackbox_exporter', 'caddy', 'cloudflared', 'fnox', 'loki',
         'node_exporter', 'pitchfork', 'prometheus', 'rclone', 'restic')
PROFILES = {'forgejo': ('forgejo',), 'alloy': ('observability',),
            'grafana': ('grafana', 'notifications')}
BACKUP_FILES = ('coordinator.py', 'backup.sh', 'restore.sh', 'prune.sh',
                'courier.sh', 'courier.py', 'open_capsule.py', 'README.md')
BACKUP_ENV = {'RCLONE_CONFIG_R2_TYPE', 'RCLONE_CONFIG_R2_PROVIDER', 'RCLONE_CONFIG_R2_REGION',
              'RCLONE_CONFIG_R2_ENDPOINT', 'RCLONE_CONFIG_R2_ACCESS_KEY_ID',
              'RCLONE_CONFIG_R2_SECRET_ACCESS_KEY', 'RCLONE_CONFIG_R2_SESSION_TOKEN',
              'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN'}


def trusted_dir(path, private=False):
    path = Path(path)
    # macOS has OS-owned /etc -> private/etc and /var -> private/var aliases.
    # Normalize only these fixed aliases, never arbitrary deployment symlinks.
    if os.uname().sysname == 'Darwin' and path.parts[1:2] in (('etc',), ('var',)):
        path = Path('/private') / path.relative_to('/')
    for parent in reversed(path.parents):
        check_dir(parent)
    check_dir(path, private)


def reject_acl(path):
    if os.uname().sysname == 'Darwin':
        mode = subprocess.check_output(['/bin/ls', '-lde', str(path)], text=True).split()[0]
        if '+' in mode:
            raise ValueError('ACL on protected path: ' + str(path))


def check_dir(path, private=False):
    s = path.lstat()
    if not stat.S_ISDIR(s.st_mode) or s.st_uid != 0 or s.st_mode & (0o077 if private else 0o022):
        raise ValueError('Unsafe directory (do not automatically chown it): ' + str(path))
    reject_acl(path)


def directory(path, mode=0o755):
    created = False
    if not path.exists() and not path.is_symlink():
        trusted_dir(path.parent)
        path.mkdir(mode=mode)
        created = True
    trusted_dir(path, private=mode == 0o700)
    if created:
        # mkdir's mode is masked by the installer's 077 umask. Only widen a new,
        # validated directory, through a descriptor that cannot follow symlinks.
        fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fchmod(fd, mode)
        finally:
            os.close(fd)
        trusted_dir(path, private=mode == 0o700)
    if (stat.S_IMODE(path.lstat().st_mode) & mode) != mode:
        raise ValueError('Directory lacks required access; review permissions explicitly: ' + str(path))


def atomic_bytes(data, dst, mode=0o755):
    trusted_dir(dst.parent)
    # os.replace replaces a destination symlink itself; it never follows it.
    fd, tmp = tempfile.mkstemp(prefix='.install-', dir=dst.parent)
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
            os.fchmod(out.fileno(), mode)
            os.fchown(out.fileno(), 0, 0)
        os.replace(tmp, dst)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def install(src, dst, mode=0o755):
    src = src.resolve(strict=True)
    if not src.is_file():
        raise ValueError('Expected regular source file: ' + str(src))
    atomic_bytes(src.read_bytes(), dst, mode)


def check_macho_tree(root):
    """Reject a Python distribution linked back into Homebrew or a user prefix."""
    magic = {b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}
    for path in root.rglob('*'):
        if not path.is_file():
            continue
        with path.open('rb') as stream:
            if stream.read(4) not in magic:
                continue
        def internal_reference(value):
            for token, base in (('@loader_path/', path.parent), ('@executable_path/', root / 'bin')):
                if value.startswith(token):
                    resolved = (base / value[len(token):]).resolve()
                    if resolved != root and root not in resolved.parents:
                        raise ValueError('Python loader path escapes runtime: ' + value)
                    return True
            return False

        deps = subprocess.check_output(['/usr/bin/otool', '-L', str(path)], text=True)
        for line in deps.splitlines()[1:]:
            dep = line.strip().split(' (', 1)[0]
            if dep.startswith(('/usr/lib/', '/System/Library/')) or internal_reference(dep):
                continue
            if dep.startswith('@rpath/') and '..' not in Path(dep).parts:
                continue  # All embedded rpaths are checked below, for every Mach-O file.
            raise ValueError('Python has an external dependency: ' + dep)
        loads = subprocess.check_output(['/usr/bin/otool', '-l', str(path)], text=True)
        for match in re.finditer(r'cmd LC_RPATH\n\s*cmdsize \d+\n\s*path (.*?) \(offset', loads):
            rpath = match.group(1)
            if not internal_reference(rpath + '/'):
                raise ValueError('Python has an external rpath: ' + rpath)


def install_python(source):
    # Use the selected mise interpreter only at this explicit trusted deployment boundary.
    prefix = Path(subprocess.check_output([str(source.resolve()), '-I', '-S', '-c',
        'import sys; print(sys.base_prefix)'], text=True).strip()).resolve(strict=True)
    if not prefix.is_dir() or prefix in (Path('/'), Path('/usr'), Path('/usr/local')):
        raise ValueError('Select a self-contained mise Python >= 3.11, not system/Homebrew Python')
    runtime = Path(tempfile.mkdtemp(prefix='python-', dir=BASE))
    shutil.copytree(prefix, runtime, dirs_exist_ok=True, symlinks=False)
    for path in [runtime, *runtime.rglob('*')]:
        s = path.lstat()
        if not (stat.S_ISDIR(s.st_mode) or stat.S_ISREG(s.st_mode)):
            raise ValueError('Python runtime contains a non-regular file: ' + str(path))
        os.chown(path, 0, 0)
        os.chmod(path, 0o755 if path.is_dir() or s.st_mode & 0o111 else 0o644)
    check_macho_tree(runtime)
    python = runtime / 'bin/python3'
    code = ('import sys, pathlib, tomllib, ssl, sqlite3, ctypes, zlib; '
            'p=pathlib.Path(sys.base_prefix).resolve(); '
            'assert p == pathlib.Path(sys.argv[1]).resolve(), (p, sys.path); '
            'assert all(p == pathlib.Path(s).resolve() or p in pathlib.Path(s).resolve().parents '
            'for s in sys.path), sys.path')
    subprocess.run([str(python), '-I', '-S', '-c', code, str(runtime)], check=True,
                   cwd='/var/empty', env={'PATH': '/usr/bin:/bin', 'HOME': '/var/root',
                                          'OPENSSL_CONF': '/dev/null', 'OPENSSL_MODULES': str(runtime / 'lib/ossl-modules')})
    # A regular, protected wrapper preserves relocatable stdlib/framework lookup.
    wrapper = ('#!/bin/sh\nexport OPENSSL_CONF=/dev/null\n'
               'export OPENSSL_MODULES=' + str(runtime / 'lib/ossl-modules') + '\n'
               'exec ' + str(python) + ' -I -S "$@"\n')
    atomic_bytes(wrapper.encode(), BIN / 'python3')


def toml(data):
    trusted_dir(BIN)
    s = (BIN / 'python3').lstat()
    if not stat.S_ISREG(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
        raise ValueError('Deploy the protected Python runtime first')
    reject_acl(BIN / 'python3')
    code = 'import json,sys,tomllib; print(json.dumps(tomllib.loads(sys.stdin.read())))'
    return json.loads(subprocess.check_output([str(BIN / 'python3'), '-I', '-S', '-c', code],
        input=data, cwd='/var/empty', env={'PATH': '/usr/bin:/bin'}))


def validate_fnox_config(config):
    """The unattended root runtime supports age only, without executable extensions."""
    providers = set()
    references = []

    def inspect(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if (key in {'command', 'hook', 'hooks', 'pre_exec', 'post_exec',
                            'import', 'plugins', 'leases', 'targets', 'files'} or
                    key.endswith(('_command', '_hook', '_hooks'))):
                    raise ValueError('Unsupported executable/external fnox configuration: ' + key)
                if key == 'providers':
                    if not isinstance(value, dict):
                        raise ValueError('Fnox providers must be a table')
                    for name, provider in value.items():
                        if not isinstance(provider, dict) or provider.get('type') != 'age':
                            raise ValueError('Root fnox supports only age providers: ' + name)
                        providers.add(name)
                elif key in {'provider', 'default_provider'}:
                    references.append(value)
                inspect(value)
        elif isinstance(node, list):
            for value in node:
                inspect(value)

    inspect(config)
    if not providers:
        raise ValueError('Root fnox requires an explicitly declared age provider')
    for name in references:
        if not isinstance(name, str) or name not in providers:
            raise ValueError('Fnox reference must name a declared age provider')


def validate_environment_names(names):
    # These values reach a protected interpreter immediately after fnox exec,
    # before its second stage can discard the rest of the environment.
    for name in names:
        if (not re.fullmatch(r'[A-Z][A-Z0-9_]*', name) or
            name.startswith(('DYLD_', 'LD_', 'PYTHON', 'SUDO_', 'FNOX_', 'BASH_', 'OPENSSL_', 'PITCHFORK_', 'ENV')) or
            name in {'PATH', 'HOME', 'USER', 'LOGNAME', 'SHELL', 'IFS', 'CDPATH',
                     'ZDOTDIR', 'RUBYOPT', 'PERL5OPT', 'NODE_OPTIONS', 'GIT_CONFIG',
                     'GIT_CONFIG_COUNT', 'GIT_EXEC_PATH', 'RESTIC_PASSWORD_COMMAND', 'RCLONE_CONFIG'}):
            raise ValueError('Unsafe secret environment name: ' + name)


def environment_names(config):
    result = {}
    for service, profiles in PROFILES.items():
        names = set(config.get('secrets', {}))
        for profile in profiles:
            names.update(config['profiles'][profile].get('secrets', {}))
        validate_environment_names(names)
        if not names:
            raise ValueError('No explicit secrets for ' + service)
        result[service] = sorted(names)
    # The coordinator gets only the backup profile's recognized backend credentials
    # and connection settings, never inherited unrelated secrets or fnox controls.
    backup_names = set(config['profiles']['backup'].get('secrets', {}))
    validate_environment_names(backup_names)
    result['backup'] = sorted(backup_names & BACKUP_ENV)
    if not result['backup']:
        raise ValueError('Declare backup backend credentials explicitly in the backup profile')
    return result


def log_directory(path, uid, gid, legacy_uid):
    trusted_dir(path.parent)
    try:
        path.mkdir(mode=0o750)
    except FileExistsError:
        pass
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        s = os.fstat(fd)
        if s.st_uid not in {0, uid, legacy_uid}:
            raise ValueError('Unexpected log directory owner: ' + str(path))
        reject_acl(path)
        # Explicit migration of these fixed data directories, never code/config parents.
        os.fchown(fd, uid, gid)
        os.fchmod(fd, 0o750)
    finally:
        os.close(fd)


def log_file(path, uid, gid, legacy_uid):
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
    try:
        s = os.fstat(fd)
        if not stat.S_ISREG(s.st_mode) or s.st_nlink != 1 or s.st_uid not in {0, uid, legacy_uid}:
            raise ValueError('Unsafe log file: ' + str(path))
        reject_acl(path)
        os.fchown(fd, uid, gid)
        os.fchmod(fd, 0o640)
    finally:
        os.close(fd)


def prepare_logging(source):
    mac = pwd.getpwnam('mac').pw_uid
    caddy = pwd.getpwnam('svc_caddy').pw_uid
    gid = grp.getgrnam('observability').gr_gid
    logs = Path('/var/log/services')
    log_directory(logs, 0, gid, mac)
    log_directory(Path('/var/log/caddy'), caddy, gid, caddy)
    for name, uid in (('pitchfork.log', 0), ('supervisor.log', 0), ('postfix.log', mac)):
        log_file(logs / name, uid, gid, mac)
    trusted_dir(source.parent)
    s = source.lstat()
    if not stat.S_ISREG(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
        raise ValueError('Unsafe newsyslog source: ' + str(source))
    reject_acl(source)
    directory(Path('/etc/newsyslog.d'))
    install(source, Path('/etc/newsyslog.d/services.conf'), 0o644)


def deploy_config(source):
    directory(Path('/etc/pitchfork'))
    data = source.read_bytes()
    config = toml(data)
    if config.get('settings', {}).get('supervisor', {}).get('user') != 'root':
        raise ValueError('Pitchfork supervisor must run as root')
    general = config.get('settings', {}).get('general', {})
    if general.get('shell') != '/bin/sh -c' or general.get('mise') is not False:
        raise ValueError('Privileged Pitchfork must use the system shell, without mise wrapping')
    expected = {name: str(BASE / 'secret-service') + ' ' + name for name in PROFILES}
    expected['backup'] = str(BASE / 'backup/launch.sh')
    expected['log_shipper_pitchfork'] = str(BASE / 'ship-pitchfork.sh')
    for name, daemon in config['daemons'].items():
        if daemon.get('user') not in {'root', 'mac', 'svc_caddy', 'svc_cloudflared', 'svc_observability'}:
            raise ValueError('Every daemon needs an explicit approved UID: ' + name)
        if daemon.get('user') == 'root':
            if (name not in expected or daemon.get('run') != expected[name] or
                set(daemon) - {'user', 'run', 'boot_start', 'depends', 'cron'}):
                raise ValueError('Unexpected root daemon command/environment: ' + name)
        elif name in expected:
            raise ValueError('Protected launchers require root: ' + name)
    prepare_logging(BASE / 'newsyslog.conf')
    atomic_bytes(data, Path('/etc/pitchfork/config.toml'), 0o644)
    # Do not use `pitchfork boot enable`: it could register the invoking mise path.
    plist = {'Label': 'pitchfork', 'ProgramArguments': [str(BIN / 'pitchfork'), 'supervisor', 'run', '--boot'],
             'UserName': 'root', 'WorkingDirectory': '/var/empty', 'RunAtLoad': True,
             'KeepAlive': True, 'EnvironmentVariables': {
                 'PATH': '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root',
                 'PITCHFORK_USER': 'root', 'PITCHFORK_SUPERVISOR_AUTO_START': 'false',
                                  'XDG_CONFIG_HOME': '/etc'},
             'StandardOutPath': '/var/log/services/supervisor.log',
             'StandardErrorPath': '/var/log/services/supervisor.log'}
    trusted_dir(Path('/Library/LaunchDaemons'))
    atomic_bytes(plistlib.dumps(plist), Path('/Library/LaunchDaemons/pitchfork.plist'), 0o644)


def deploy_backup():
    runtime = BASE / 'backup'
    directory(runtime)
    for name in BACKUP_FILES:
        src = REPO / 'services/backup' / name
        data = src.read_bytes()
        if name.endswith(('.py', '.sh')):
            if b'/Users/mac/Developer/configuration' in data:
                raise ValueError('Backup still references the user checkout: ' + name)
            data = data.replace(b'/usr/bin/python3', b'/usr/local/bin/python3')
        atomic_bytes(data, runtime / name, 0o644 if name == 'README.md' else 0o755)
    launch = (b'#!/bin/sh\nset -eu\n'
              b'[ "$(/usr/bin/id -u)" = 0 ] || exit 77\ncd /var/empty\n'
              b'exec /usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin '
              b'HOME=/var/root USER=root LOGNAME=root '
              b'/usr/local/bin/python3 -I -S /usr/local/libexec/mac-server/backup_launcher.py "$@"\n')
    atomic_bytes(launch, runtime / 'launch.sh')
    # Keep only a compatibility entry point here; leave existing migration data alone.
    legacy = Path('/usr/local/libexec/home-backup')
    directory(legacy)
    atomic_bytes(b'#!/bin/sh\nexec /usr/local/libexec/mac-server/backup/launch.sh "$@"\n',
                 legacy / 'launch.sh')


def main():
    p = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    p.add_argument('action', choices=('tools', 'deploy', 'stage', 'config'))
    p.add_argument('--tool', action='append', default=[], metavar='NAME=PATH')
    p.add_argument('--config', type=Path, help='explicitly reviewed fnox ciphertext source')
    a = p.parse_args()
    if a.action in ('deploy', 'stage'):
        if not a.config:
            p.error('--config must name the reviewed fnox ciphertext source')
        # Preserve the caller's relative input before changing to a protected cwd.
        a.config = a.config.absolute()
    elif a.config is not None:
        p.error('--config is valid only with deploy or stage')
    if os.geteuid() != 0:
        raise SystemExit('Root required')
    if a.config is not None and not a.config.is_file():
        raise ValueError('Reviewed fnox config must be an existing regular file')
    os.umask(0o077)
    os.chdir('/var/empty')
    for path in (Path('/usr/local'), BIN, Path('/usr/local/libexec'), BASE):
        directory(path)
    if a.action in ('tools', 'deploy', 'stage'):
        tools = dict(item.split('=', 1) for item in a.tool)
        if set(tools) != set(TOOLS) | {'python3'}:
            raise ValueError('Supply exactly the pinned tools and python3')
        install_python(Path(tools['python3']))
        for name in TOOLS:
            install(Path(tools[name]), BIN / name)
        # These user-owned Homebrew executables are only opened AFTER the UID drop.
        for name in ('forgejo', 'grafana'):
            atomic_bytes(('#!/bin/sh\nexec /opt/homebrew/bin/' + name + ' "$@"\n').encode(), BIN / name)
    if a.action in ('deploy', 'stage'):
        trusted_dir(Path('/etc/fnox'), private=True)
        key = Path('/etc/fnox/operational.key').lstat()
        if not stat.S_ISREG(key.st_mode) or key.st_uid != 0 or key.st_mode & 0o077:
            raise ValueError('Provision a root-only regular /etc/fnox/operational.key first')
        reject_acl(Path('/etc/fnox/operational.key'))
        data = a.config.read_bytes()
        config = toml(data)
        validate_fnox_config(config)
        names = environment_names(config)
        atomic_bytes(data, Path('/etc/fnox/config.toml'), 0o600)
        for name in ('secret-service', 'secret_launcher.py', 'secret_child.py', 'backup_launcher.py',
                     'backup_child.py', 'ship-pitchfork.sh', 'ship_pitchfork.py', 'activate.py', 'install.py',
                     'newsyslog.conf'):
            install(Path(__file__).resolve().parent / name, BASE / name,
                    0o644 if name == 'newsyslog.conf' else 0o755)
        atomic_bytes(json.dumps(names, sort_keys=True).encode(), BASE / 'environment.json', 0o600)
        deploy_backup()
    if a.action in ('deploy', 'config'):
        deploy_config(REPO / 'pitchfork.toml')
    if a.action == 'stage':
        print('Staged protected runtime and fnox config only; no Pitchfork config, plist, logging setup or service-control commands.')
    else:
        print('Installed protected files. No keys decrypted; no service-control commands run.')


if __name__ == '__main__':
    main()
