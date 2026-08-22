import sys

from core.logger import banner

from commands.categories import run as categories_run
from commands.home_header import run as home_header_run
from commands.banner_slider import run as banner_slider_run
from commands.horizontal_properties import run as horizontal_properties_run
from commands.property_card import run as property_card_run
from commands.home_screen import run as home_screen_run
from commands.home import run as home_run

from commands.details_profile import run as details_profile_run
from commands.all import run as all_run

from commands.analyze import run as analyze_run
from commands.doctor import run as doctor_run
from commands.fix import run as fix_run
from commands.stats import run as stats_run
from commands.report import run as report_run
from commands.migrate import run as migrate_run
from commands.test import run as test_run

def usage():
    print("Usage:")
    print("  python tools\\aqar.py analyze")
    print("  python tools\\aqar.py doctor")
    print("  python tools\\aqar.py stats")
    print("  python tools\\aqar.py report")
    print("  python tools\\aqar.py fix")
    print("  python tools\\aqar.py migrate")
    print("  python tools\\aqar.py migrate <dart_file>")
    print("  python tools\\aqar.py update <target>")
    print("  python tools\\aqar.py test")


def update_usage():
    print("Update Targets:")
    print("  home")
    print("  details")
    print("  categories")
    print("  home_header")
    print("  banner_slider")
    print("  horizontal_properties")
    print("  property_card")
    print("  home_screen")
    print("  all")


def main():

    banner()

    if len(sys.argv) < 2:
        usage()
        return

    command = sys.argv[1].lower()

    try:

        if command == "analyze":
            analyze_run()

        elif command == "doctor":
            doctor_run()

        elif command == "stats":
            stats_run()

        elif command == "report":
            report_run()

        elif command == "fix":
            fix_run()

        elif command == "migrate":
            migrate_run()

        elif command == "update":

            if len(sys.argv) < 3:
                update_usage()
                return

            target = sys.argv[2].lower()

            if target == "home":
                home_run()

            elif target == "details":
                details_profile_run()

            elif target == "categories":
                categories_run()

            elif target == "home_header":
                home_header_run()

            elif target == "banner_slider":
                banner_slider_run()

            elif target == "horizontal_properties":
                horizontal_properties_run()

            elif target == "property_card":
                property_card_run()

            elif target == "home_screen":
                home_screen_run()

            elif target == "all":
                all_run()

            elif command == "test":
                test_run()

            else:
                print(f"Unknown update target: {target}")

        else:
            usage()

    except Exception as e:
        print()
        print("=" * 60)
        print("ERROR")
        print("=" * 60)
        print(e)


if __name__ == "__main__":
    main()