def register(engine):

    # Material Elevation

    engine.add(
        r"elevation\s*:\s*16",
        "elevation: AqarElevation.xl(context)",
    )

    engine.add(
        r"elevation\s*:\s*14",
        "elevation: AqarElevation.lg(context)",
    )

    engine.add(
        r"elevation\s*:\s*12",
        "elevation: AqarElevation.lg(context)",
    )

    engine.add(
        r"elevation\s*:\s*10",
        "elevation: AqarElevation.md(context)",
    )

    engine.add(
        r"elevation\s*:\s*8",
        "elevation: AqarElevation.md(context)",
    )

    engine.add(
        r"elevation\s*:\s*6",
        "elevation: AqarElevation.sm(context)",
    )

    engine.add(
        r"elevation\s*:\s*5",
        "elevation: AqarElevation.sm(context)",
    )

    engine.add(
        r"elevation\s*:\s*4",
        "elevation: AqarElevation.sm(context)",
    )

    engine.add(
        r"elevation\s*:\s*3",
        "elevation: AqarElevation.xs(context)",
    )

    engine.add(
        r"elevation\s*:\s*2",
        "elevation: AqarElevation.xs(context)",
    )

    engine.add(
        r"elevation\s*:\s*1",
        "elevation: AqarElevation.none",
    )