from __future__ import annotations

import os
from pathlib import Path

from get_package_version import main as print_package_version


def read_ref_file(path: Path) -> str | None:
    if not path.exists():
        return None
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.split("#", 1)[0].strip()
        if value:
            return value
    return None


def main() -> None:
    env_ref = os.environ.get("PJSIP_REF", "").strip()
    if env_ref:
        print(env_ref)
        return

    ref_file = Path(__file__).resolve().parents[1] / "pjsua2" / "_pjproject_ref"
    ref = read_ref_file(ref_file)
    if ref:
        print(ref)
        return

    print_package_version()


if __name__ == "__main__":
    main()
