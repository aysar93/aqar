from commands.categories import run as categories_run
from commands.home_header import run as home_header_run
from commands.banner_slider import run as banner_slider_run
from commands.horizontal_properties import run as horizontal_properties_run
from commands.property_card import run as property_card_run
from commands.home_screen import run as home_screen_run
def run():
    print("[HOME]")

    categories_run()
    home_header_run()
    home_screen_run()
    banner_slider_run()
    horizontal_properties_run()
    property_card_run()

    print()
    print("✓ Home updated successfully")