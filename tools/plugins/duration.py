def register(engine):

    # Animation Durations

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*1000\s*\)",
        "AqarDurations.slow",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*800\s*\)",
        "AqarDurations.slow",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*700\s*\)",
        "AqarDurations.medium",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*600\s*\)",
        "AqarDurations.medium",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*500\s*\)",
        "AqarDurations.medium",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*400\s*\)",
        "AqarDurations.normal",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*350\s*\)",
        "AqarDurations.normal",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*300\s*\)",
        "AqarDurations.normal",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*250\s*\)",
        "AqarDurations.fast",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*200\s*\)",
        "AqarDurations.fast",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*150\s*\)",
        "AqarDurations.fast",
    )

    engine.add(
        r"Duration\(\s*milliseconds\s*:\s*100\s*\)",
        "AqarDurations.instant",
    )