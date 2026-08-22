def register(engine):

    # Icon Sizes

    engine.add(
        r"size\s*:\s*32",
        "size: AqarSizes.iconXl(context)",
    )

    engine.add(
        r"size\s*:\s*30",
        "size: AqarSizes.iconXl(context)",
    )

    engine.add(
        r"size\s*:\s*28",
        "size: AqarSizes.iconLg(context)",
    )

    engine.add(
        r"size\s*:\s*26",
        "size: AqarSizes.iconLg(context)",
    )

    engine.add(
        r"size\s*:\s*24",
        "size: AqarSizes.icon(context)",
    )

    engine.add(
        r"size\s*:\s*22",
        "size: AqarSizes.icon(context)",
    )

    engine.add(
        r"size\s*:\s*20",
        "size: AqarSizes.iconMd(context)",
    )

    engine.add(
        r"size\s*:\s*18",
        "size: AqarSizes.iconSm(context)",
    )

    engine.add(
        r"size\s*:\s*16",
        "size: AqarSizes.iconSm(context)",
    )

    engine.add(
        r"size\s*:\s*14",
        "size: AqarSizes.iconXs(context)",
    )

    engine.add(
        r"size\s*:\s*12",
        "size: AqarSizes.iconXs(context)",
    )

    # IconData

    engine.add(
        r"Icon\(",
        "Icon(",
    )