from __future__ import annotations

import argparse
import shutil
from pathlib import Path


GENERATED_PATTERNS = [
    "_pjsua2*.so",
    "_pjsua2*.pyd",
    "_pjsua2*.dylib",
    "*.dll",
    "*.dylib",
]


def remove_old_artifacts(package_dir: Path) -> None:
    for pattern in GENERATED_PATTERNS:
        for path in package_dir.glob(pattern):
            path.unlink()

    generated_python = package_dir / "pjsua2.py"
    if generated_python.exists():
        generated_python.unlink()


def copy_first_match(source_dir: Path, package_dir: Path, pattern: str) -> bool:
    matches = sorted(source_dir.rglob(pattern))
    if not matches:
        return False

    shutil.copy2(matches[0], package_dir / matches[0].name)
    return True


def copy_all_matches(source_dir: Path, package_dir: Path, pattern: str) -> int:
    count = 0
    for path in sorted(source_dir.rglob(pattern)):
        shutil.copy2(path, package_dir / path.name)
        count += 1
    return count


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--package-dir", required=True)
    args = parser.parse_args()

    source_dir = Path(args.source_dir).resolve()
    package_dir = Path(args.package_dir).resolve()

    if not source_dir.exists():
        raise SystemExit(f"Source directory does not exist: {source_dir}")

    package_dir.mkdir(parents=True, exist_ok=True)
    remove_old_artifacts(package_dir)

    generated_python = source_dir / "pjsua2.py"
    if not generated_python.exists():
        raise SystemExit(f"Missing generated wrapper: {generated_python}")
    shutil.copy2(generated_python, package_dir / "pjsua2.py")

    binary_found = False
    for binary_pattern in ("_pjsua2*.so", "_pjsua2*.pyd", "_pjsua2*.dylib"):
        binary_found = copy_first_match(source_dir, package_dir, binary_pattern) or binary_found

    if not binary_found:
        raise SystemExit(f"No compiled PJSUA2 extension found in {source_dir}")

    copy_all_matches(source_dir, package_dir, "*.dll")
    copy_all_matches(source_dir, package_dir, "*.dylib")


if __name__ == "__main__":
    main()
