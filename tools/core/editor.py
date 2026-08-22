from pathlib import Path

from core.backup import create_backup


def read_file(file_path: str) -> str:
    return Path(file_path).read_text(
        encoding="utf-8",
    )


def write_file(file_path: str, content: str):
    Path(file_path).write_text(
        content,
        encoding="utf-8",
        newline="\n",
    )

    print("✓ File saved")


def replace_once(
    content: str,
    old: str,
    new: str,
):

    if new in content:
        return content, False

    count = content.count(old)

    if count == 0:
        raise ValueError(
            f"Pattern not found:\n{old}"
        )

    if count > 1:
        raise ValueError(
            f"Pattern found {count} times:\n{old}"
        )

    return content.replace(old, new, 1), True


def update_file(
    file_path: str,
    replacements: list[tuple[str, str]],
):

    backup = create_backup(file_path)

    content = read_file(file_path)

    replaced = 0

    for old, new in replacements:

        content, changed = replace_once(
            content,
            old,
            new,
        )

        if changed:
            replaced += 1

    write_file(file_path, content)

    print()
    print("=" * 50)
    print("Update Report")
    print("=" * 50)
    print(f"Backup      : {backup}")
    print(f"Replacements: {replaced}")
    print("Status      : SUCCESS")