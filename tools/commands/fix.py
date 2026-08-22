from pathlib import Path
from core.logger import section


FIXES = [
    (
        "withOpacity(",
        "withValues(alpha: ",
        ")",
    ),
]


def run():

    section("FIX")

    total_files = 0
    total_changes = 0

    for file in Path("lib").rglob("*.dart"):

        text = file.read_text(
            encoding="utf-8",
        )

        original = text

        changes = 0

        for old, new, suffix in FIXES:

            while old in text:

                start = text.find(old)

                end = text.find(
                    suffix,
                    start + len(old),
                )

                if end == -1:
                    break

                value = text[
                    start + len(old):end
                ]

                text = (
                    text[:start]
                    + new
                    + value
                    + ")"
                    + text[end + 1:]
                )

                changes += 1

        if text != original:

            file.write_text(
                text,
                encoding="utf-8",
            )

            total_files += 1
            total_changes += changes

            print(
                f"✓ {file} ({changes})"
            )

    print()
    print("=" * 50)
    print(f"FILES   : {total_files}")
    print(f"CHANGES : {total_changes}")