"""Private rolling backup of authoritative world and accounts, never under www."""
import io
import json
import os
from pathlib import Path
import sqlite3
import tarfile
import tempfile
import time

os.umask(0o077)
state = Path(os.environ.get('TUTU_STATE_DIR', '/var/lib/tutuworld'))
destination = Path('/var/backups/tutuworld')
destination.mkdir(parents=True, exist_ok=True)
name = 'tutuworld-' + time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()) + '.tar.gz'
with tempfile.TemporaryDirectory(prefix='tutu-backup-') as folder:
    files = []
    world = state / 'world.json'
    if world.exists():
        data = world.read_bytes()
        json.loads(data)
        files.append(('world.json', data))
    if (state / 'accounts.sqlite3').exists():
        target = Path(folder) / 'accounts.sqlite3'
        with sqlite3.connect(state / 'accounts.sqlite3') as source, sqlite3.connect(target) as copy:
            source.backup(copy)
        files.append(('accounts.sqlite3', target.read_bytes()))
    with tarfile.open(destination / (name + '.tmp'), 'w:gz') as archive:
        for filename, data in files:
            info = tarfile.TarInfo(filename)
            info.size = len(data)
            info.mode = 0o600
            info.mtime = int(time.time())
            archive.addfile(info, io.BytesIO(data))
    os.replace(destination / (name + '.tmp'), destination / name)
for file in destination.glob('tutuworld-*.tar.gz'):
    if time.time() - file.stat().st_mtime > 14 * 86400:
        file.unlink()
print('TutuWorld backup complete')
