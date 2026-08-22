from pathlib import Path

from core.logger import section
from core.regex_engine import RegexEngine
from core.plugin_loader import load_plugins


INPUT = Path("tools/tests/input")
EXPECTED = Path("tools/tests/expected")


def run():

    section("AQAR TOOLKIT TEST")

    engine = RegexEngine()
    load_plugins(engine)

    passed = 0
    failed = 0

    for input_file in sorted(INPUT.glob("*.dart")):

        expected_file = EXPECTED / input_file.name

        if not expected_file.exists():
            print(f"✗ Missing expected file: {input_file.name}")
            failed += 1
            continue

        source = input_file.read_text(
            encoding="utf-8",
        )

        expected = expected_file.read_text(
            encoding="utf-8",
        )

        result, _ = engine.run(source)

        if result.strip() == expected.strip():

            print(f"✓ {input_file.name}")
            passed += 1

        else:

            print(f"✗ {input_file.name}")
            failed += 1

    print()
    print("=" * 60)
    print("TEST REPORT")
    print("=" * 60)
    print(f"Passed : {passed}")
    print(f"Failed : {failed}")
    print("=" * 60)

    if failed == 0:
        print("Toolkit Ready ✔")
    else:
        print("Toolkit Needs Fixes ✗")