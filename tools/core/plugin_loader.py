from importlib import import_module

PLUGINS = [

    # Stable
    "plugins.colors",
    "plugins.text",

    # Disabled temporarily
    # "plugins.spacing",
    # "plugins.radius",
    # "plugins.sizedbox",
    # "plugins.icons",
    # "plugins.duration",
    # "plugins.elevation",
    # "plugins.imports",
]


def load_plugins(engine):

    loaded = 0

    for plugin in PLUGINS:

        module = import_module(plugin)

        if hasattr(module, "register"):
            module.register(engine)
            loaded += 1

    return loaded