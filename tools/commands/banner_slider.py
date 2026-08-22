from core.editor import update_file

FILE = "lib/widgets/banner_slider.dart"

def run():
    update_file(
        FILE,
        [
            (
                "height: 180,",
                "height: AqarSizes.bannerHeight(context),",
            ),
            (
    """child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),""",
    """child: ClipRRect(
                    borderRadius: BorderRadius.circular(AqarRadius.lg(context)),""",
),
            (
                "fontSize: 22,",
                "fontSize: AqarText.bannerTitle(context),",
            ),
        ],
    )