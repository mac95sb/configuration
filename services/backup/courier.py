#!/usr/bin/python3
"""Non-destructive local iCloud handoff. This does NOT prove cloud durability."""
import argparse
import fcntl
import hashlib
import json
import math
import os
import pwd
import time
import uuid
from pathlib import Path
import shutil
import tempfile


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def write_metric(directory, name, gid=None):
    """Publish one complete textfile, root/service-group 0640 (mac owns courier's file)."""
    if name not in ('backup_last_success_seconds', 'backup_courier_last_success_seconds'):
        raise RuntimeError('unsupported backup metric')
    if gid is None:
        gid = pwd.getpwnam('svc_observability').pw_gid
    directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    temporary = '.' + name + '-' + uuid.uuid4().hex
    try:
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=directory_fd)
        with os.fdopen(fd, 'w') as f:
            os.fchown(f.fileno(), -1, gid)
            os.fchmod(f.fileno(), 0o640)
            f.write(name + ' ' + str(int(time.time())) + '\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, name + '.prom', src_dir_fd=directory_fd, dst_dir_fd=directory_fd)
        os.fsync(directory_fd)
    finally:
        try:
            os.unlink(temporary, dir_fd=directory_fd)
        except FileNotFoundError:
            pass
        os.close(directory_fd)


def select_receipt(source, snapshot):
    selected = None
    matches = 0
    for receipt in source.glob('receipt-*.json'):
        if receipt.is_symlink() or not receipt.is_file():
            raise RuntimeError('invalid recovery receipt: ' + receipt.name)
        data = json.loads(receipt.read_text())
        if snapshot is not None and data['snapshot'] != snapshot:
            continue
        created = data.get('created')
        if (type(created) not in (int, float) or created < 0 or
                (isinstance(created, float) and not math.isfinite(created))):
            raise RuntimeError('invalid receipt created timestamp: ' + receipt.name)
        if snapshot is not None:
            matches += 1
            selected = receipt, data
        elif selected is None or created > selected[1]['created']:
            selected = receipt, data
            matches = 1
        elif created == selected[1]['created']:
            matches += 1
    if selected is None:
        raise RuntimeError('no matching completed recovery receipt')
    if matches != 1:
        raise RuntimeError('ambiguous recovery receipt; select a unique snapshot')
    return selected


def courier(source, destination, snapshot=None, metrics=None, metric_gid=None):
    receipt, data = select_receipt(source, snapshot)
    destination.mkdir(parents=True, exist_ok=True)
    artifacts = dict(data.get('repository_files', {}))
    artifacts.update(data['artifacts'])
    artifacts[receipt.name] = sha(receipt)
    # Receipt is published last, so partial runs can be retried safely.
    for name, expected in artifacts.items():
        relative = Path(name)
        if (relative.is_absolute() or '..' in relative.parts or
                any(part.startswith('.') for part in relative.parts) or
                (len(relative.parts) > 1 and relative.parts[0] != 'restic-v1')):
            raise RuntimeError('invalid artifact name')
        src = source / name
        if src.is_symlink() or not src.is_file() or sha(src) != expected:
            raise RuntimeError('missing/modified artifact: ' + name)
        dst = destination / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        if os.path.lexists(dst):
            if dst.is_symlink() or sha(dst) != expected:
                raise RuntimeError('immutable destination differs: ' + name)
            continue
        fd, temporary = tempfile.mkstemp(prefix='.partial-', dir=destination)
        try:
            with os.fdopen(fd, 'wb') as f, src.open('rb') as inp:
                shutil.copyfileobj(inp, f)
                f.flush()
                os.fsync(f.fileno())
            if sha(Path(temporary)) != expected:
                raise RuntimeError('courier copy differs')
            os.link(temporary, dst)
        finally:
            os.unlink(temporary)
    if metrics is not None:
        write_metric(metrics, 'backup_courier_last_success_seconds', metric_gid)
    print('Copied and read back local iCloud Drive files. Cloud upload/durability is NOT verified.')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--snapshot')
    a = p.parse_args()
    if os.geteuid() == 0:
        raise SystemExit('Run the courier as mac, not root.')
    destination = Path.home() / 'Library/Mobile Documents/com~apple~CloudDocs/Backups/configuration/recovery-v1'
    destination.mkdir(parents=True, exist_ok=True)
    with (destination / '.courier.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        courier(Path('/var/db/home-backup-export/recovery-v1'), destination, a.snapshot,
                metrics=Path('/Users/svc_observability/textfile'))
