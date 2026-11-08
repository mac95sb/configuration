"""Read fixed global root logs; write only the protected group-readable log sink."""
import grp
import os
from pathlib import Path
import stat
import signal
import subprocess
import sys

sys.path.insert(0, '/usr/local/libexec/mac-server')
from secret_launcher import BASE, trusted

LOG = Path('/var/log/services/pitchfork.log')
# Exclude this capture daemon to avoid feeding its own errors back into the sink.
DAEMONS = ('caddy', 'cloudflared', 'node_exporter', 'soc_metrics', 'blackbox',
           'prometheus', 'loki', 'alloy', 'grafana', 'forgejo', 'log_shipper_postfix', 'backup')


def append_record(record, path=LOG, gid=None):
    if gid is None:
        gid = grp.getgrnam('observability').gr_gid
    # The directory is root-owned and not group-writable. O_NOFOLLOW plus fstat
    # also refuses symlink/FIFO/hardlink sinks without ever truncating a target.
    flags = os.O_WRONLY | os.O_APPEND | os.O_NOFOLLOW | os.O_NONBLOCK
    try:
        fd = os.open(path, flags | os.O_CREAT | os.O_EXCL, 0o640)
        created = True
    except FileExistsError:
        fd = os.open(path, flags)
        created = False
    try:
        if created:
            os.fchown(fd, 0, gid)
            os.fchmod(fd, 0o640)
        s = os.fstat(fd)
        if (not stat.S_ISREG(s.st_mode) or s.st_uid != 0 or s.st_gid != gid or
            stat.S_IMODE(s.st_mode) != 0o640 or s.st_nlink != 1):
            raise RuntimeError('Unsafe pitchfork log sink')
        view = memoryview(record)
        while view:
            view = view[os.write(fd, view):]
    finally:
        os.close(fd)
    # Reopening each record follows newsyslog rotation, never a stale descriptor.


def main():
    if os.geteuid() != 0 or len(sys.argv) != 1:
        raise SystemExit('Root required; log capture accepts no arguments')
    def stop(signum, frame):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, stop)
    for path in (BASE / 'ship-pitchfork.sh', BASE / 'ship_pitchfork.py', '/usr/local/bin/pitchfork'):
        trusted(path)
    trusted(LOG.parent, directory=True)
    env = {'PATH': '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': '/var/root',
           'USER': 'root', 'LOGNAME': 'root', 'PITCHFORK_USER': 'root',
           'PITCHFORK_SUPERVISOR_AUTO_START': 'false', 'XDG_CONFIG_HOME': '/etc'}
    command = ['/usr/local/bin/pitchfork', 'logs', '--json', '--follow', '--no-pager', '-n', '0',
               *['global/' + name for name in DAEMONS]]
    with subprocess.Popen(command, cwd='/var/empty', env=env, stdout=subprocess.PIPE) as process:
        try:
            for record in process.stdout:
                append_record(record)
            code = process.wait()
            if code:
                raise SystemExit(code)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == '__main__':
    main()
