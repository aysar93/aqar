def register(engine):

    # Height

    engine.add(
        r"SizedBox\(\s*height\s*:\s*40\s*\)",
        "SizedBox(height: AqarSpacing.xxxl(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*36\s*\)",
        "SizedBox(height: AqarSpacing.xxxl(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*32\s*\)",
        "SizedBox(height: AqarSpacing.xxl(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*30\s*\)",
        "SizedBox(height: AqarSpacing.xxl(context))",
    )

    engine.add(
        r"SizedBox\(\s*height\s*:\s*28\s*\)",
        "SizedBox(height: AqarSpacing.xl(context))",
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

    # Width

    engine.add(
        r"SizedBox\(\s*width\s*:\s*40\s*\)",
        "SizedBox(width: AqarSpacing.xxxl(context))",
    )

    engine.add(
        r"SizedBox\(\s*width\s*:\s*32\s*\)",
        "SizedBox(width: AqarSpacing.xxl(context))",
    )

    engine.add(
        r"SizedBox\(\s*width\s*:\s*24\s*\)",
        "SizedBox(width: AqarSpacing.xl(context))",
    )

    engine.add(
        r"SizedBox\(\s*width\s*:\s*20\s*\)",
        "SizedBox(width: AqarSpacing.lg(context))",
    )

    engine.add(
        r"SizedBox\(\s*width\s*:\s*16\s*\)",
        "SizedBox(width: AqarSpacing.lg(context))",
    )

    engine.add(
        r"SizedBox\(\s*width\s*:\s*12\s*\)",
        "SizedBox(width: AqarSpacing.md(context))",
    )

    engine.add(
        r"SizedBox\(\s*width\s*:\s*8\s*\)",
        "SizedBox(width: AqarSpacing.sm(context))",
    )

    engine.add(
        r"SizedBox\(\s*width\s*:\s*4\s*\)",
        "SizedBox(width: AqarSpacing.xs(context))",
    )