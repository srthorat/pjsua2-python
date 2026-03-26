from pathlib import Path

from setuptools import Distribution, setup
from setuptools.command.build_py import build_py as _build_py


PACKAGE_DIR = Path(__file__).parent / "pjsua2"


def generated_extension_exists() -> bool:
    patterns = ("_pjsua2*.so", "_pjsua2*.pyd", "_pjsua2*.dylib")
    return any(PACKAGE_DIR.glob(pattern) for pattern in patterns)


class build_py(_build_py):
    def run(self):
        wrapper = PACKAGE_DIR / "pjsua2.py"
        if not wrapper.exists() or not generated_extension_exists():
            raise RuntimeError(
                "Generated PJSUA2 bindings are missing. Run a platform build script first "
                "or build the wheel through cibuildwheel so the before-build step stages "
                "the upstream SWIG artifacts."
            )
        super().run()


class BinaryDistribution(Distribution):
    def has_ext_modules(self):
        return True


setup(distclass=BinaryDistribution, cmdclass={"build_py": build_py})