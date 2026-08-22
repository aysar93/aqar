from pathlib import Path


def count(path):
    p = Path(path)

    if not p.exists():
        return 0

    return len(list(p.rglob("*.dart")))


def run():

    print("[DOCTOR]")
    print()

    print(f"Screens : {count('lib/screens')}")
    print(f"Widgets : {count('lib/widgets')}")
    print(f"Services: {count('lib/services')}")
    print(f"Models  : {count('lib/models')}")

    print()

    checks = [
        ("core/design", Path("lib/core/design")),
        ("core/responsive", Path("lib/core/responsive")),
        ("theme", Path("lib/theme")),
        ("tools/backups", Path("tools/backups")),
    ]

    print("Status")
    print("-" * 40)

    ok = True

    for name, path in checks:
        exists = path.exists()

        if exists:
            print(f"✓ {name}")
        else:
            print(f"✗ {name}")
            ok = False

    print()

    if ok:
        print("PROJECT STATUS : HEALTHY")
    else:
        print("PROJECT STATUS : NEEDS ATTENTION")