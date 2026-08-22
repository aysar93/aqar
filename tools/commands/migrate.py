from pathlib import Path
import sys

from core.logger import section
from core.regex_engine import RegexEngine
from core.plugin_loader import load_plugins
from core.backup import (
    backup_project,
    backup_file,
    restore_project,
)
from core.validator import validate

ROOT = Path("lib")


def _collect_files():

    if len(sys.argv) >= 3:

        target = Path(sys.argv[2])

        if target.exists():
            return [target]

        print(f"File not found: {target}")
        return []

    return list(ROOT.rglob("*.dart"))


def run():

    section("MIGRATE")

    files = _collect_files()

    if not files:
        return

    single_file = len(files) == 1

    # ==========================
    # Backup
    # ==========================

    if single_file:
        session = backup_file(str(files[0]))
    else:
        session = backup_project()

    # ==========================
    # Engine
    # ==========================

    engine = RegexEngine()
    plugins = load_plugins(engine)

    total_files = 0
    total_changes = 0

    for file in files:

        try:

            text = file.read_text(
                encoding="utf-8",
                errors="ignore",
            )

            new_text, changes = engine.run(text)

            if changes:

                file.write_text(
                    new_text,
                    encoding="utf-8",
                )

                total_files += 1
                total_changes += changes

                print(f"✓ {file} ({changes})")

        except Exception as e:

            print(f"✗ {file}")
            print(e)

    # ==========================
    # Validation (Project Only)
    # ==========================

    if not single_file:

        if not validate():

            print()
            print("=" * 60)
            print("VALIDATION FAILED")
            print("Restoring backup...")
            print("=" * 60)

            try:
                restore_project(session)
                print("✓ Project restored successfully.")
            except Exception as e:
                print("Restore failed:")
                print(e)

            return

    else:

        print()
        print("=" * 60)
        print("Single file migration completed.")
        print("Validation skipped.")
        print("=" * 60)

    # ==========================
    # Report
    # ==========================

    print()
    print("=" * 60)
    print("MIGRATION REPORT")
    print("=" * 60)
    print(f"Plugins Loaded : {plugins}")
    print(f"Files Checked  : {len(files)}")
    print(f"Files Changed  : {total_files}")
    print(f"Total Changes  : {total_changes}")
    print("=" * 60)