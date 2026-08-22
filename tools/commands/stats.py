from pathlib import Path


def run():

    print("[STATS]")
    print()

    dart_files = list(
        Path("lib").rglob("*.dart")
    )

    total_lines = 0
    total_classes = 0
    total_methods = 0

    for file in dart_files:

        text = file.read_text(
            encoding="utf-8",
            errors="ignore",
        )

        total_lines += len(
            text.splitlines()
        )

        total_classes += text.count(
            "class "
        )

        total_methods += (
            text.count("Widget ")
            + text.count("Future<")
            + text.count("void ")
        )

    print(f"Dart Files : {len(dart_files)}")
    print(f"Lines      : {total_lines:,}")
    print(f"Classes    : {total_classes}")
    print(f"Methods    : {total_methods}")

    print()

    avg = (
        total_lines / len(dart_files)
        if dart_files
        else 0
    )

    print(
        f"Average Lines/File : {avg:.1f}"
    )