from core.editor import update_file

FILE = "lib/screens/home_screen.dart"


def run():
    update_file(
        FILE,
        [
            (
                "padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),",
                "padding: EdgeInsets.fromLTRB(AqarSpacing.screen(context), 8, AqarSpacing.screen(context), 20),",
            ),
            (
                """const BannerSlider(),

              const SizedBox(height: 24),""",
                """const BannerSlider(),

              SizedBox(height: AqarSpacing.xl(context)),""",
            ),
            (
                """HorizontalPropertiesSection(
                title: "⭐ العقارات المميزة",""",
                """SizedBox(height: AqarSpacing.xl(context)),

              HorizontalPropertiesSection(
                title: "⭐ العقارات المميزة",""",
            ),
            (
                """const FeaturedOfficesSection(),

              const SizedBox(height: 32),""",
                """const FeaturedOfficesSection(),

              SizedBox(height: AqarSpacing.sectionLarge(context)),""",
            ),
            (
                """const WhyAqarSection(),

              const SizedBox(height: 4),""",
                """const WhyAqarSection(),

              SizedBox(height: AqarSpacing.sm(context)),""",
            ),
        ],
    )