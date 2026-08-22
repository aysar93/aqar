import subprocess
from pathlib import Path

FLUTTER = r"c:\flutter\bin\flutter.bat"


def validate():

    print()
    print("=" * 60)
    print("VALIDATING PROJECT")
    print("=" * 60)

    if not Path(FLUTTER).exists():
        raise FileNotFoundError(
            f"Flutter not found:\n{FLUTTER}"
        )

    result = subprocess.run(
        [FLUTTER, "analyze"],
        text=True,
        capture_output=True,
        cwd=".",
    )

    if result.returncode == 0:

        print("✓ Validation Passed")
        return True

    print(result.stdout)

    if result.stderr:
        print(result.stderr)

    print()
    print("=" * 60)
    print("VALIDATION FAILED")
    print("=" * 60)

    return False