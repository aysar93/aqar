from core.editor import update_file

FILE = "lib/widgets/home/home_header.dart"


def run():
    update_file(
        FILE,
        [
            (
                "radius: Responsive.w(context, 0.055),",
                "radius: AqarSizes.avatarRadius(context),",
            ),
            (
                "size: Responsive.icon(context, 28),",
                "size: AqarSizes.avatarIcon(context),",
            ),
            (
                "size: Responsive.icon(context, 26),",
                "size: AqarSizes.headerIcon(context),",
            ),
            (
                "width: Responsive.headerButton(context),",
                "width: AqarSizes.headerButton(context),",
            ),
            (
                "height: Responsive.headerButton(context),",
                "height: AqarSizes.headerButton(context),",
            ),
        ],
    )