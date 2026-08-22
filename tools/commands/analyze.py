from core.metrics import score
from core.scanner import scan
from core.report import print_table
from core.constants import PATTERNS


def progress(value):

    filled = value // 5

    return (
        "█" * filled +
        "░" * (20 - filled)
    )


def run():

    print()
    print("=" * 50)
    print("AQAR DESIGN REPORT")
    print("=" * 50)

    value = score()

    print()
    print(f"Design Score : {value}%")
    print(progress(value))

    for title, pattern in PATTERNS.items():

        print_table(
            title.upper(),
            scan(pattern),
        )