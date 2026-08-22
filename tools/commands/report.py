from pathlib import Path
from core.logger import section
from core.scanner import scan
from core.metrics import score
from core.constants import PATTERNS


def run():

    section("REPORT")

    value = score()

    print()
    print("=" * 60)
    print("AQAR PROJECT REPORT")
    print("=" * 60)

    print(f"Design Score : {value}%")
    print()

    dart_files = list(Path("lib").rglob("*.dart"))

    total_lines = 0

    for file in dart_files:
        try:
            total_lines += len(
                file.read_text(
                    encoding="utf-8",
                    errors="ignore",
                ).splitlines()
            )
        except:
            pass

    print(f"Dart Files : {len(dart_files)}")
    print(f"Lines      : {total_lines:,}")

    print()

    total_issues = 0

    for title, pattern in PATTERNS.items():

        data = scan(pattern)

        count = sum(
            item["count"]
            for item in data
        )

        total_issues += count

        print(
            f"{title:<18}: {count}"
        )

    print()
    print("=" * 60)
    print(f"TOTAL ISSUES : {total_issues}")
    print("=" * 60)

    print()

    if value >= 90:
        print("Status : EXCELLENT")

    elif value >= 75:
        print("Status : VERY GOOD")

    elif value >= 50:
        print("Status : GOOD")

    elif value >= 25:
        print("Status : NEEDS IMPROVEMENT")

    else:
        print("Status : CRITICAL")