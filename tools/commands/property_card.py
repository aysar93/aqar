from core.editor import update_file

FILE = "lib/widgets/property_horizontal_home_card.dart"


def run():
    update_file(
        FILE,
        [
            (
                "width: 300,",
                "width: AqarSizes.propertyCardWidth(context),",
            ),
            (
                """Image.asset(
                                image.toString(),
                                width: double.infinity,
                                height: 185,""",
                """Image.asset(
                                image.toString(),
                                width: double.infinity,
                                height: AqarSizes.propertyImageHeight(context),""",
            ),
            (
                """CachedNetworkImage(
                                imageUrl: image.toString(),
                                width: double.infinity,
                                height: 185,""",
                """CachedNetworkImage(
                                imageUrl: image.toString(),
                                width: double.infinity,
                                height: AqarSizes.propertyImageHeight(context),""",
            ),
            (
                "fontSize: 18,",
                "fontSize: AqarText.propertyTitle(context),",
            ),
            (
                "fontSize: 17,",
                "fontSize: AqarText.price(context),",
            ),
        ],
    )