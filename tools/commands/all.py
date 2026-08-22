from commands.home import run as home_run
from commands.details_profile import run as details_run


def run():
    print("[ALL]")

    home_run()
    details_run()

    print()
    print("=" * 50)
    print("ALL UPDATES COMPLETED")
    print("=" * 50)