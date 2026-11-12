"""Bootstrap fresh temporary test databases without PocketBase opening a browser."""
import secrets
import subprocess
from pathlib import Path


def prepare_test_database(root, temporary):
    root, temporary = Path(root).resolve(), Path(temporary).resolve()
    data = temporary / 'data'
    if not temporary.is_dir() or data.exists():
        raise RuntimeError('Expected a fresh temporary test directory')
    result = subprocess.run([
        str(root / 'server/runtime/pocketbase.exe'), 'superuser', 'create',
        'bootstrap@invalid.example', secrets.token_urlsafe(36),
        f'--dir={data}', f'--migrationsDir={root / "server/pb_migrations"}',
        f'--hooksDir={root / "server/pb_hooks"}'
    ], capture_output=True, timeout=30,
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    if result.returncode:
        raise RuntimeError('Temporary PocketBase bootstrap failed (private output suppressed)')
