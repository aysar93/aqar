from pathlib import Path
from datetime import datetime
import shutil

BACKUP_ROOT = Path("tools/backups")


def _create_session():

    session = BACKUP_ROOT / datetime.now().strftime("%Y%m%d_%H%M%S")
    session.mkdir(parents=True, exist_ok=True)

    return session


def backup_project(root="lib"):

    session = _create_session()

    root = Path(root)

    total = 0

    for file in root.rglob("*.dart"):

        destination = session / file.relative_to(root)

        destination.parent.mkdir(parents=True, exist_ok=True)

        shutil.copy2(file, destination)

        total += 1

    print()
    print("=" * 60)
    print("BACKUP CREATED")
    print("=" * 60)
    print(f"Folder : {session}")
    print(f"Files  : {total}")
    print("=" * 60)

    return session


def backup_file(file_path):

    session = _create_session()

    source = Path(file_path)

    destination = session / source.name

    destination.parent.mkdir(parents=True, exist_ok=True)

    shutil.copy2(source, destination)

    return session


def restore_project(session, root="lib"):

    session = Path(session)
    root = Path(root)

    if not session.exists():
        raise FileNotFoundError(session)

    restored = 0

    for file in session.rglob("*.dart"):

        destination = root / file.relative_to(session)

        destination.parent.mkdir(parents=True, exist_ok=True)

        shutil.copy2(file, destination)

        restored += 1

    print()
    print("=" * 60)
    print("PROJECT RESTORED")
    print("=" * 60)
    print(f"Files : {restored}")
    print("=" * 60)


# ==========================================
# Backward Compatibility
# ==========================================

def create_backup(file_path):
    """
    توافق مع الإصدارات القديمة التي تستدعي create_backup().
    """
    return backup_file(file_path)