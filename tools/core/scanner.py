from pathlib import Path
from collections import defaultdict

from core.constants import EXCLUDED


def dart_files():

    for file in Path("lib").rglob("*.dart"):

        skip = False

        for item in EXCLUDED:

            if item in str(file):
                skip = True
                break

        if not skip:
            yield file


def scan(pattern):

    result = defaultdict(int)

    for file in dart_files():

        try:

            text = file.read_text(
                encoding="utf-8"
            )

            c = text.count(pattern)

            if c:
                result[
                    str(file).replace("\\", "/")
                ] = c

        except Exception:
            pass

    return result