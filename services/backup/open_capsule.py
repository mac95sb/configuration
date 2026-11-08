#!/usr/bin/python3
"""Extract only after checking an independently retained SHA-256 with trusted local tools.

Age protects confidentiality and detects ciphertext corruption; it does not authenticate
who created a capsule. Anyone with the public recipients can encrypt a replacement.
Bundled hashes are not independent proof of sender identity.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import tarfile
import tempfile


def verify_capsule_digest(archive, expected_sha256):
    if not isinstance(expected_sha256, str) or not re.fullmatch(r'[0-9a-fA-F]{64}', expected_sha256):
        raise RuntimeError('an independently retained 64-character CAPSULE_SHA256 is required')
    digest = hashlib.sha256()
    with archive.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != expected_sha256.lower():
        raise RuntimeError('capsule SHA-256 differs from the independently retained recovery record')


def open_capsule(archive, identity, destination, age, expected_sha256):
    # This check must precede even private staging, and must never use downloaded metadata as its expected hash.
    verify_capsule_digest(archive, expected_sha256)
    if os.path.lexists(destination):
        raise RuntimeError('destination must not exist')
    destination.mkdir(mode=0o700, parents=False)
    # Leave a failed directory in place for investigation, never reuse it implicitly.
    with tempfile.TemporaryDirectory(dir=destination) as tmp:
        clear = Path(tmp) / 'capsule.tar'
        subprocess.run([str(age), '-d', '-i', str(identity), '-o', str(clear), str(archive)], check=True)
        with tarfile.open(clear) as tar:
            members = tar.getmembers()
            for member in members:
                path = Path(member.name)
                if (path.is_absolute() or '..' in path.parts or not path.parts or
                        path.parts[0] != 'capsule' or not (member.isdir() or member.isfile())):
                    raise RuntimeError('unsafe capsule member: ' + member.name)
            for member in members:
                target = destination / member.name
                if member.isdir():
                    target.mkdir(mode=0o700, exist_ok=True)
                else:
                    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    with target.open('xb') as out, tar.extractfile(member) as inp:
                        while True:
                            data = inp.read(1024 * 1024)
                            if not data:
                                break
                            out.write(data)
                    target.chmod(0o700 if member.name.startswith('capsule/tools/') else 0o600)
        metadata = json.loads((destination / 'capsule/metadata.json').read_text())
        for name, info in metadata['tools'].items():
            if Path(name).name != name:
                raise RuntimeError('unsafe tool name')
            digest = hashlib.sha256((destination / 'capsule/tools' / name).read_bytes()).hexdigest()
            if digest != info['sha256']:
                raise RuntimeError('tool hash mismatch: ' + name)
    print('Extracted capsule. It contains encrypted config and password, NOT an age identity.')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('archive', type=Path)
    p.add_argument('--identity', required=True, type=Path)
    p.add_argument('--sha256', required=True, help='capsule hash from an independently retained offline record')
    p.add_argument('--destination', required=True, type=Path)
    p.add_argument('--age', type=Path, default=Path('/usr/local/bin/age'))
    a = p.parse_args()
    os.umask(0o077)
    open_capsule(a.archive, a.identity, a.destination, a.age, a.sha256)
