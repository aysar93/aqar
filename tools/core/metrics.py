from core.scanner import scan


def score():

    penalties = 0

    penalties += len(scan("Color("))
    penalties += len(scan("fontSize:"))
    penalties += len(scan("EdgeInsets."))
    penalties += len(scan("BorderRadius.circular("))

    value = max(
        0,
        100 - penalties // 5,
    )

    return value