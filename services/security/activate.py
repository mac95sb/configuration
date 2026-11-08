"""Explicit maintenance activation of the deployed root Pitchfork supervisor."""
import json
import os
from pathlib import Path
import plistlib
import pwd
import subprocess
import sys
import time

sys.path.insert(0, '/usr/local/libexec/mac-server')
from install import prepare_logging
from secret_launcher import BASE, trusted, validate_runtime

PLIST = Path('/Library/LaunchDaemons/pitchfork.plist')
ROOT_ENV = {'PATH': '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root',
            'USER': 'root', 'LOGNAME': 'root', 'PITCHFORK_USER': 'root',
            'PITCHFORK_SUPERVISOR_AUTO_START': 'false', 'XDG_CONFIG_HOME': '/etc'}


def run(command):
    return subprocess.run(command, check=True, cwd='/var/empty', env=ROOT_ENV,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                                    timeout=120 if 'stop' in command else 30).stdout


def loaded(domain):
    result = subprocess.run(['/bin/launchctl', 'print', domain], cwd='/var/empty', env=ROOT_ENV,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=15)
    if result.returncode == 0:
        return True
    if 'Could not find service' in result.stderr or 'Could not find domain' in result.stderr:
        return False
    raise RuntimeError('Cannot inspect launchd job ' + domain + ': ' + result.stderr)


def client(user, *args):
    env = {**ROOT_ENV, 'HOME': '/var/root' if user == 'root' else '/Users/mac',
           'USER': user, 'LOGNAME': user, 'PITCHFORK_USER': user}
    if user == 'mac':
        # Any legacy user config is read only AFTER dropping privileges.
        env['XDG_CONFIG_HOME'] = '/Users/mac/.config'
    return ['/usr/bin/sudo', '-n', '-H', '-u', user, '--', '/usr/bin/env', '-i',
            *[key + '=' + value for key, value in env.items()], '/usr/local/bin/pitchfork', *args]


def status(user):
    data = json.loads(run(client(user, 'supervisor', 'status', '--json')))
    state = data.get('status')
    if state not in ('up', 'down'):
        raise RuntimeError('Cannot safely determine ' + user + ' supervisor state')
    return state


def stop_supervisor(user):
    if status(user) == 'down':
        return
    run(client(user, 'stop', '--all'))
    run(client(user, 'supervisor', 'stop'))
    deadline = time.monotonic() + 15
    while status(user) != 'down':
        if time.monotonic() >= deadline:
            raise RuntimeError(user + ' supervisor did not stop; refusing duplicate supervisor')
        time.sleep(0.5)


def main():
    if os.geteuid() != 0 or len(sys.argv) != 1:
        raise SystemExit('Root required; activation accepts no arguments')
    validate_runtime()
    for path in (BASE / 'activate.py', BASE / 'install.py', BASE / 'newsyslog.conf',
                 BASE / 'ship-pitchfork.sh', BASE / 'ship_pitchfork.py',
                 BASE / 'backup_child.py', '/usr/local/bin/pitchfork', '/etc/pitchfork/config.toml', PLIST):
        trusted(path)
    plist = plistlib.loads(PLIST.read_bytes())
    if (plist.get('Label') != 'pitchfork' or plist.get('UserName') != 'root' or
        plist.get('ProgramArguments') != ['/usr/local/bin/pitchfork', 'supervisor', 'run', '--boot'] or
        plist.get('KeepAlive') is not True or plist.get('WorkingDirectory') != '/var/empty' or
        plist.get('EnvironmentVariables') != {key: ROOT_ENV[key] for key in
            ('PATH', 'HOME', 'PITCHFORK_USER', 'PITCHFORK_SUPERVISOR_AUTO_START', 'XDG_CONFIG_HOME')}):
        raise RuntimeError('Unexpected boot plist; redeploy before activation')
    prepare_logging(BASE / 'newsyslog.conf')
    mac_uid = pwd.getpwnam('mac').pw_uid
    domains = [domain for domain in ('gui/' + str(mac_uid) + '/pitchfork', 'system/pitchfork') if loaded(domain)]
    # Disable KeepAlive first, but let clients stop daemons in dependency order
    # before stopping the supervisors. No user-owned executable runs as root.
    for domain in domains:
        run(['/bin/launchctl', 'disable', domain])
    stop_supervisor('mac')
    stop_supervisor('root')
    for domain in domains:
        run(['/bin/launchctl', 'bootout', domain])
    run(['/bin/launchctl', 'enable', 'system/pitchfork'])
    run(['/bin/launchctl', 'bootstrap', 'system', str(PLIST)])
    deadline = time.monotonic() + 15
    while status('root') != 'up':
        if time.monotonic() >= deadline:
            raise RuntimeError('Root supervisor did not become ready; inspect /var/log/services/supervisor.log')
        time.sleep(0.5)
    print('Activated the protected global root supervisor; legacy mac supervisor stopped.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as exc:
        raise SystemExit('Activation stopped: ' + str(exc) + '. Fix the cause and rerun daemon:activate.')
