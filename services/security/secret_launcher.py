"""Fixed root fnox entry points. Secret values are passed only in the environment."""

import os
from pathlib import Path
import stat
import subprocess
import sys

BASE = Path('/usr/local/libexec/mac-server')
PROFILES = {'forgejo': 'forgejo', 'alloy': 'observability', 'grafana': 'grafana,notifications'}
COMMANDS = {
    'forgejo': ('svc_forgejo', ['/Users/mac/Developer/configuration/services/forgejo/start.sh']),
    'alloy': ('svc_observability', ['/usr/local/bin/alloy', 'run',
        '/Users/mac/Developer/configuration/services/alloy/config.alloy',
        '--storage.path=/Users/svc_observability/alloy-data', '--server.http.listen-addr=127.0.0.1:12345']),
    'grafana': ('svc_observability', ['/usr/local/bin/grafana', 'server',
        '--config=/Users/mac/Developer/configuration/services/grafana/config.ini',
        '--homepath=/opt/homebrew/opt/grafana/share/grafana', '--packaging=brew',
        'cfg:default.paths.logs=/Users/svc_observability/grafana-logs',
        'cfg:default.paths.data=/Users/svc_observability/grafana-data',
        'cfg:default.paths.plugins=/Users/svc_observability/grafana-plugins']),
}


def reject_acl(path):
    if sys.platform == 'darwin':
        mode = subprocess.check_output(['/bin/ls', '-lde', str(path)], text=True).split()[0]
        if '+' in mode:
            raise RuntimeError('ACL on protected path: ' + str(path))


def trusted(path, private=False, directory=False):
    path = Path(path)
    if sys.platform == 'darwin' and path.parts[1:2] in (('etc',), ('var',)):
        path = Path('/private') / path.relative_to('/')
    for parent in reversed(path.parents):
        s = parent.lstat()
        if not stat.S_ISDIR(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
            raise RuntimeError('Unsafe parent: ' + str(parent))
        reject_acl(parent)
    s = path.lstat()
    kind = stat.S_ISDIR if directory else stat.S_ISREG
    if not kind(s.st_mode) or s.st_uid != 0 or s.st_mode & (0o077 if private else 0o022):
        raise RuntimeError('Unsafe privileged runtime: ' + str(path))
    reject_acl(path)


def service_arg(args):
    if len(args) != 1 or args[0] not in PROFILES:
        raise SystemExit('Expected exactly one service: forgejo, alloy, grafana')
    if os.geteuid() != 0:
        raise SystemExit('Root is required')
    return args[0]


def validate_runtime():
    for path in ('/usr/local/bin/fnox', '/usr/local/bin/age', '/usr/local/bin/python3',
                 BASE / 'secret-service', BASE / 'secret_launcher.py', BASE / 'secret_child.py'):
        trusted(path)
    trusted('/etc/fnox', private=True, directory=True)
    trusted('/etc/fnox/config.toml', private=True)
    trusted('/etc/fnox/operational.key', private=True)
    trusted(BASE / 'environment.json', private=True)


def root_environment():
    # fnox provider-specific key_file/identity settings outrank FNOX_AGE_KEY_FILE.
    # The inline root-only identity takes precedence; it is never put in argv or
    # preserved through sudo. No caller-supplied environment is inherited.
    return {'PATH': '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root',
            'USER': 'root', 'LOGNAME': 'root', 'PITCHFORK_USER': 'root',
                        'PITCHFORK_SUPERVISOR_AUTO_START': 'false', 'XDG_CONFIG_HOME': '/etc',
                        'FNOX_CONFIG_DIR': '/etc/fnox',
                        'FNOX_AGE_KEY_FILE': '/etc/fnox/operational.key',
            'FNOX_AGE_KEY': Path('/etc/fnox/operational.key').read_text()}


def main():
    service = service_arg(sys.argv[1:])
    validate_runtime()
    env = root_environment()
    os.chdir('/var/empty')
    os.execve('/usr/local/bin/fnox', ['fnox', 'exec', '--non-interactive', '--no-daemon',
        '--config', '/etc/fnox/config.toml', '--profile', PROFILES[service], '--',
        '/usr/local/bin/python3', '-I', str(BASE / 'secret_child.py'), service], env)


if __name__ == '__main__':
    main()
