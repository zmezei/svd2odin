#!/usr/bin/env python3
"""
svd2odin-regress — Regression testing for svd2odin.py

Downloads SVD files listed in ci/tests.yml, generates Odin register
definitions, and verifies the output compiles with `odin build`.

Inspired by svd2rust-regress from the rust-embedded project.

Usage:
    python3 ci/svd2odin-regress.py                       # run all tests
    python3 ci/svd2odin-regress.py -c STM32F051          # filter by chip
    python3 ci/svd2odin-regress.py -m STMicro            # filter by manufacturer
    python3 ci/svd2odin-regress.py -v                     # verbose output

Requirements:
    - Odin compiler on PATH
    - PyYAML (pip install pyyaml)
    - Network access to download SVD files
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent
TESTS_FILE = Path(__file__).resolve().parent / "tests.yml"
SVD2ODIN = REPO_ROOT / "tools" / "svd2odin.py"


def load_tests() -> list[dict]:
    with open(TESTS_FILE) as f:
        tests = yaml.safe_load(f)
    return tests or []


def download_svd(url: str, dest: Path) -> bool:
    try:
        urllib.request.urlretrieve(url, dest)
        return True
    except Exception as e:
        print(f"  FAILED to download SVD: {e}")
        return False


def run_test(test: dict, verbose: bool) -> bool:
    chip = test["chip"]
    mfgr = test.get("mfgr", "Unknown")
    url = test["svd_url"]

    print(f"[{chip}] ({mfgr})")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        svd_path = tmpdir / f"{chip}.svd"
        out_path = tmpdir / "registers.odin"

        # Download SVD
        print(f"  Downloading SVD from {url}...")
        if not download_svd(url, svd_path):
            return False

        # Generate Odin code
        print(f"  Generating Odin code...")
        result = subprocess.run(
            [
                sys.executable, str(SVD2ODIN),
                str(svd_path), str(out_path),
                "--package", "mcu",
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"  FAILED to generate code:")
            if result.stderr:
                print(result.stderr)
            if result.stdout:
                print(result.stdout)
            return False

        # Check compilation
        print(f"  Checking compilation...")
        result = subprocess.run(
            [
                "odin", "build", str(out_path), "-file",
                "-target:freestanding_arm32",
                "-target-features:thumb-mode,armv6s-m",
                "-no-thread-local",
                "-default-to-nil-allocator",
                "-no-entry-point",
                "-disable-unwind",
                "-vet",
                "-build-mode:obj",
                f"-out:{tmpdir / 'out'}",
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"  FAILED compilation check:")
            if result.stderr:
                print(result.stderr)
            if result.stdout:
                print(result.stdout)
            return False

        if verbose and result.stderr:
            print(f"  Compiler output:")
            print(result.stderr)

        print(f"  PASS")
        return True


def main():
    parser = argparse.ArgumentParser(
        description="Regression testing for svd2odin.py"
    )
    parser.add_argument(
        "-c", "--chip",
        help="Filter by chip name (case-sensitive)",
    )
    parser.add_argument(
        "-m", "--manufacturer",
        help="Filter by manufacturer (case-sensitive)",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose output",
    )
    args = parser.parse_args()

    # Check odin is available
    if not shutil.which("odin"):
        print("Error: odin compiler not found on PATH", file=sys.stderr)
        sys.exit(1)

    all_tests = load_tests()

    # Filter tests
    tests = all_tests
    if args.chip:
        tests = [t for t in tests if args.chip in t.get("chip", "")]
    if args.manufacturer:
        tests = [t for t in tests if args.manufacturer in t.get("mfgr", "")]

    if not tests:
        print("No tests matched the given filters.", file=sys.stderr)
        sys.exit(1)

    print(f"Running {len(tests)} test(s)...\n")

    passed = 0
    failed = 0
    for test in tests:
        if run_test(test, args.verbose):
            passed += 1
        else:
            failed += 1
        print()

    print(f"Results: {passed} passed, {failed} failed, {len(tests)} total")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
