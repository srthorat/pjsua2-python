from __future__ import annotations

import re
from pathlib import Path


def main() -> None:
    version_file = Path(__file__).resolve().parents[1] / "pjsua2" / "_version.py"
    contents = version_file.read_text(encoding="utf-8")
    match = re.search(r'__version__\s*=\s*"([^"]+)"', contents)
    if not match:
        raise SystemExit(f"Could not read package version from {version_file}")
    print(match.group(1))


if __name__ == "__main__":
    main()