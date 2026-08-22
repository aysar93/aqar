from core.editor import update_file

FILE = "lib/screens/property_details.dart"


def run():
    update_file(
        FILE,
        [
            (
                "padding: const EdgeInsets.all(16),",
                "padding: EdgeInsets.all(AqarSpacing.page(context)),",
            ),
        ],
    )