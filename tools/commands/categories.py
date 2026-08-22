from core.editor import update_file

FILE = "lib/widgets/home/categories_section.dart"


def run():
    update_file(
        FILE,
        [
            (
                "height: 112,",
                "height: AqarSizes.categorySectionHeight(context),",
            ),
            (
                "width: 92,",
                "width: AqarSizes.categoryWidth(context),",
            ),
            (
                "size: 28,",
                "size: AqarSizes.categoryIcon(context),",
            ),
            (
                "fontSize: 13,",
                "fontSize: AqarText.small(context),",
            ),
            (
                "padding: const EdgeInsets.all(12),",
                "padding: EdgeInsets.all(AqarSpacing.md(context)),",
            ),
        ],
    )