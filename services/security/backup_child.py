"""Discard the fnox identity/control environment before starting the root coordinator."""
import json
import os
import sys

sys.path.insert(0, '/usr/local/libexec/mac-server')
from backup_launcher import RUNTIME, coordinator_args, validate_backup_runtime
from secret_launcher import BASE


def main():
    if os.geteuid() != 0:
        raise SystemExit('Root is required')
    args = coordinator_args(sys.argv[1:])
    validate_backup_runtime()
    names = json.loads((BASE / 'environment.json').read_text())['backup']
    env = {'PATH': '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root',
           'USER': 'root', 'LOGNAME': 'root', 'PITCHFORK_USER': 'root',
           'PITCHFORK_SUPERVISOR_AUTO_START': 'false', 'XDG_CONFIG_HOME': '/etc'}
    env.update({name: os.environ[name] for name in names if name in os.environ})
    os.chdir('/var/empty')
    os.execve('/usr/local/bin/python3', ['python3', '-I', '-S', str(RUNTIME / 'coordinator.py'), *args], env)


if __name__ == '__main__':
    main()
