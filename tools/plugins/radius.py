def register(engine):

    engine.add(
        r"BorderRadius\.circular\(\s*24\s*\)",
        "BorderRadius.circular(AqarRadius.xxl(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*22\s*\)",
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

    engine.add(
        r"BorderRadius\.circular\(\s*6\s*\)",
        "BorderRadius.circular(AqarRadius.xs(context))",
    )

    engine.add(
        r"BorderRadius\.circular\(\s*4\s*\)",
        "BorderRadius.circular(AqarRadius.xs(context))",
    )