from importlib import import_module

from ._version import __version__

__all__ = ["__version__"]


def _load_bindings():
    try:
        return import_module(".pjsua2", __name__)
    except ModuleNotFoundError as exc:
        missing = {"_pjsua2", "pjsua2._pjsua2", "pjsua2.pjsua2"}
        if exc.name in missing:
            raise ImportError(
                "PJSUA2 binary bindings are not staged. Build a wheel with cibuildwheel "
                "or run the platform build script before importing this package."
            ) from exc
        raise


def __getattr__(name):
    if name == "__version__":
        return __version__

    module = _load_bindings()
    value = getattr(module, name)
    globals()[name] = value
    if name not in __all__:
        __all__.append(name)
    return value


def __dir__():
    names = set(globals())
    try:
        names.update(dir(_load_bindings()))
    except ImportError:
        pass
    return sorted(names)
