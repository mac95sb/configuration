#!/usr/bin/python3
"""Atomic Prometheus textfile publication for backup status."""
import os
import pwd
import time
import uuid


def write_metric(directory, name, gid=None):
    """Publish a complete root-owned metric file with service-group read access."""
    if name != 'backup_last_success_seconds':
        raise RuntimeError('unsupported backup metric')
    if gid is None:
        gid = pwd.getpwnam('svc_observability').pw_gid
    directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    temporary = '.' + name + '-' + uuid.uuid4().hex
    try:
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=directory_fd)
        with os.fdopen(fd, 'w') as output:
            os.fchown(output.fileno(), -1, gid)
            os.fchmod(output.fileno(), 0o640)
            output.write(name + ' ' + str(int(time.time())) + '\n')
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, name + '.prom', src_dir_fd=directory_fd, dst_dir_fd=directory_fd)
        os.fsync(directory_fd)
    finally:
        try:
            os.unlink(temporary, dir_fd=directory_fd)
        except FileNotFoundError:
            pass
        os.close(directory_fd)
