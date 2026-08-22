import re


class RegexRule:

    def __init__(self, pattern, replacement, flags=re.MULTILINE):
        self.pattern = re.compile(pattern, flags)
        self.replacement = replacement

    def apply(self, text):

        new_text, count = self.pattern.subn(
            self.replacement,
            text,
        )

        return new_text, count


class RegexEngine:

    def __init__(self):
        self.rules = []

    def add(self, pattern, replacement):
        self.rules.append(
            RegexRule(
                pattern,
                replacement,
            )
        )

    def run(self, text):

        total = 0

        for rule in self.rules:

            text, count = rule.apply(text)
            total += count

        return text, total

    def clear(self):
        self.rules.clear()