"""Fixed backup entry point; validate arguments before resolving any secret."""
import argparse
import os
from pathlib import Path
import re
import sys

sys.path.insert(0, '/usr/local/libexec/mac-server')
from secret_launcher import BASE, root_environment, trusted, validate_runtime

RUNTIME = BASE / 'backup'


def coordinator_args(argv):
    parser = argparse.ArgumentParser(allow_abbrev=False)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('init', 'backup', 'checkpoint'):
        sub.add_parser(name, allow_abbrev=False)
    for name in ('verify', 'restore'):
        recovery = sub.add_parser(name, allow_abbrev=False)
        recovery.add_argument('snapshot')
        recovery.add_argument('--repository')
        if name == 'restore':
            recovery.add_argument('--session', required=True)
            recovery.add_argument('--offline', action='store_true')
    sub.add_parser('prune', allow_abbrev=False).add_argument('--apply', action='store_true')
    args = parser.parse_args(argv or ['backup'])
    result = [args.command]
    if args.command in ('verify', 'restore'):
        if not re.fullmatch(r'[0-9a-f]{64}', args.snapshot):
            parser.error('recovery requires an exact full 64-character snapshot ID')
        result.append(args.snapshot)
        if args.repository is not None:
            repository = args.repository
            # Restic backends can spawn helpers. Limit overrides to data-only local
            # paths or the existing rclone backend, never sftp/command backends.
            local = (repository.startswith('/') and not repository.startswith('//') and
                     '..' not in Path(repository).parts)
            remote = re.fullmatch(r'rclone:[A-Za-z0-9_-]+:[A-Za-z0-9_./-]+', repository)
            if (not repository or any(ord(c) < 32 or ord(c) == 127 for c in repository) or
                not (local or remote) or '..' in repository.split('/')):
                parser.error('repository must be an absolute local path or rclone remote:path')
            result += ['--repository', repository]
        if args.command == 'restore':
            if not re.fullmatch(r'[a-zA-Z0-9_-]+', args.session):
                parser.error('restore requires a simple --session name')
            result.append('--session=' + args.session)
            if args.offline:
                result.append('--offline')
    elif args.command == 'prune' and args.apply:
        result.append('--apply')
    return result


def validate_backup_runtime():
    validate_runtime()
    for path in (BASE / 'backup_launcher.py', BASE / 'backup_child.py', RUNTIME / 'launch.sh'):
        trusted(path)
    for name in ('coordinator.py', 'backup.sh', 'restore.sh', 'prune.sh', 'courier.sh',
                 'courier.py', 'open_capsule.py'):
        trusted(RUNTIME / name)
    for name in ('restic', 'rclone', 'pitchfork'):
        trusted(Path('/usr/local/bin') / name)


def main():
    if os.geteuid() != 0:
        raise SystemExit('Root is required')
    args = coordinator_args(sys.argv[1:])
    validate_backup_runtime()
    os.chdir('/var/empty')
    os.execve('/usr/local/bin/fnox', ['fnox', 'exec', '--non-interactive', '--no-daemon',
        '--config', '/etc/fnox/config.toml', '--profile', 'backup', '--',
        '/usr/local/bin/python3', '-I', '-S', str(BASE / 'backup_child.py'), *args], root_environment())


if __name__ == '__main__':
    main()
