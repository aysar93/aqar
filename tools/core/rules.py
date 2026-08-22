import re
from core.regex_engine import RegexEngine


def build_engine():

    engine = RegexEngine()

    # --------------------------------------------------
    # Border Radius
    # --------------------------------------------------

    engine.add(
        r"BorderRadius\.circular\(\s*24\s*\)",
        "BorderRadius.circular(AqarRadius.xxl(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*20\s*\)",
        "BorderRadius.circular(AqarRadius.xl(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*18\s*\)",
        "BorderRadius.circular(AqarRadius.lg(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*16\s*\)",
        "BorderRadius.circular(AqarRadius.lg(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*14\s*\)",
        "BorderRadius.circular(AqarRadius.md(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*12\s*\)",
        "BorderRadius.circular(AqarRadius.md(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*10\s*\)",
        "BorderRadius.circular(AqarRadius.sm(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*8\s*\)",
        "BorderRadius.circular(AqarRadius.sm(context))",
    )

    # --------------------------------------------------
    # EdgeInsets.all()
    # --------------------------------------------------

    engine.add(
        r"EdgeInsets\.all\(\s*(24|22|20|18|16|15|14|12)\s*\)",
        "AqarSpacing.card(context)",
    )

    # --------------------------------------------------
    # Horizontal Padding
    # --------------------------------------------------

    engine.add(
        r"EdgeInsets\.symmetric\(\s*horizontal\s*:\s*(24|20|18|16)\s*\)",
        "AqarSpacing.page(context)",
    )

    # --------------------------------------------------
    # Vertical Padding
    # --------------------------------------------------

    engine.add(
        r"EdgeInsets\.symmetric\(\s*vertical\s*:\s*(20|18|16|14|12)\s*\)",
        "AqarSpacing.section(context)",
    )

    # --------------------------------------------------
    # SizedBox Height
    # --------------------------------------------------

    engine.add(
        r"SizedBox\(\s*height\s*:\s*32\s*\)",
        "SizedBox(height: AqarSpacing.xxl(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*24\s*\)",
        "SizedBox(height: AqarSpacing.xl(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*20\s*\)",
        "SizedBox(height: AqarSpacing.lg(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*18\s*\)",
        "SizedBox(height: AqarSpacing.lg(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*16\s*\)",
        "SizedBox(height: AqarSpacing.lg(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*14\s*\)",
        "SizedBox(height: AqarSpacing.md(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*12\s*\)",
        "SizedBox(height: AqarSpacing.md(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*10\s*\)",
        "SizedBox(height: AqarSpacing.sm(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*8\s*\)",
        "SizedBox(height: AqarSpacing.sm(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*6\s*\)",
        "SizedBox(height: AqarSpacing.xs(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*4\s*\)",
        "SizedBox(height: AqarSpacing.xs(context))",
    )

    return engine