import re


def register(engine):

    def add(pattern, replacement):
        # لا تستبدل إذا كانت الكلمة أصبحت AqarColors بالفعل
        engine.add(
            rf"(?<!Aqar){pattern}",
            replacement,
        )

    # Black

    add(r"Colors\.black", "AqarColors.black")

    # White

    add(r"Colors\.white70", "AqarColors.white70")
    add(r"Colors\.white60", "AqarColors.white60")
    add(r"Colors\.white54", "AqarColors.white54")
    add(r"Colors\.white38", "AqarColors.white38")
    add(r"Colors\.white30", "AqarColors.white30")
    add(r"Colors\.white24", "AqarColors.white24")
    add(r"Colors\.white12", "AqarColors.white12")
    add(r"Colors\.white10", "AqarColors.white10")
    add(r"Colors\.white", "AqarColors.white")

    # Grey

    add(r"Colors\.grey\.shade100", "AqarColors.grey100")
    add(r"Colors\.grey\.shade200", "AqarColors.grey200")
    add(r"Colors\.grey\.shade300", "AqarColors.grey300")
    add(r"Colors\.grey\.shade400", "AqarColors.grey400")
    add(r"Colors\.grey\.shade500", "AqarColors.grey500")
    add(r"Colors\.grey\.shade600", "AqarColors.grey600")
    add(r"Colors\.grey\.shade700", "AqarColors.grey700")
    add(r"Colors\.grey\.shade800", "AqarColors.grey800")
    add(r"Colors\.grey\.shade900", "AqarColors.grey900")
    add(r"Colors\.grey", "AqarColors.grey")

    # Common

    add(r"Colors\.red", "AqarColors.red")
    add(r"Colors\.green", "AqarColors.green")
    add(r"Colors\.blue", "AqarColors.blue")
    add(r"Colors\.orange", "AqarColors.orange")
    add(r"Colors\.amber", "AqarColors.amber")
    add(r"Colors\.yellow", "AqarColors.yellow")
    add(r"Colors\.purple", "AqarColors.purple")
    add(r"Colors\.teal", "AqarColors.teal")
    add(r"Colors\.cyan", "AqarColors.cyan")
    add(r"Colors\.transparent", "AqarColors.transparent")