#!/usr/bin/env python3
"""Check the installed database-owning applications against the reviewed baseline."""
import pathlib
import re
import subprocess
import sys
import tomllib


def main():
    baseline = tomllib.loads(pathlib.Path(__file__).with_name('versions.toml').read_text())
    failures = []
    for name, expected in baseline['homebrew'].items():
        binary = pathlib.Path('/opt/homebrew/bin') / name
        try:
            text = subprocess.check_output([str(binary), '--version'], text=True)
        except (OSError, subprocess.CalledProcessError) as exc:
            failures.append(f'{name}: cannot inspect installed binary: {exc}')
            continue
        match = re.search(r'\bversion\s+v?(\d+\.\d+\.\d+)\b', text, re.I)
        actual = match.group(1) if match else 'unrecognized'
        print(f'{name}: installed {actual}; reviewed {expected}')
        if actual != expected:
            failures.append(f'{name}: review the version and database compatibility before activation')
    if failures:
        raise SystemExit('\n'.join(failures))


if __name__ == '__main__':
    main()
