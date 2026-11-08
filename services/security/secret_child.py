"""Invoked only by the protected fnox parent; drop UID before service files are opened."""
import json
import os
import sys

# Isolated Python deliberately excludes the script directory from sys.path.
sys.path.insert(0, '/usr/local/libexec/mac-server')
from secret_launcher import BASE, COMMANDS, service_arg, trusted


def main():
    service = service_arg(sys.argv[1:])
    trusted(BASE / 'environment.json', private=True)
    names = json.loads((BASE / 'environment.json').read_text())[service]
    user, command = COMMANDS[service]
    # Pass variable names, never values, in sudo's argv. No shell or user startup files.
    env = {'PATH': '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root',
           'USER': 'root', 'LOGNAME': 'root'}
    env.update({name: os.environ[name] for name in names if name in os.environ})
    os.execve('/usr/bin/sudo', ['sudo', '-n', '-H', '--preserve-env=' + ','.join(names),
        '-u', user, '--', *command], env)


if __name__ == '__main__':
    main()
