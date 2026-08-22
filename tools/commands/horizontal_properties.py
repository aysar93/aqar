from core.editor import update_file

FILE = "lib/widgets/home/horizontal_properties_section.dart"


def run():
    update_file(
        FILE,
        [
            (
                """child: SizedBox(
            height: 420,""",
                """child: SizedBox(
            height: AqarSizes.horizontalSectionHeight(context),""",
            ),
            (
                """SizedBox(
                  height: 330,""",
                """SizedBox(
                  height: AqarSizes.horizontalCardsHeight(context),""",
            ),
            (
                "fontSize: 23,",
                "fontSize: AqarText.sectionTitle(context),",
            ),
        ],
    )