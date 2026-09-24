#!/usr/bin/env python3
"""Run the source package's pytest-style assertion functions without pytest."""

from __future__ import annotations

import importlib.util
import sys
import traceback
from pathlib import Path


EXPERIMENT = Path(__file__).resolve().parents[1]
SOURCE = EXPERIMENT / "source"
TESTS = SOURCE / "scripts" / "tests"
TEST_FILES = (
    "test_step5_f4l.py",
    "test_step5_f4l_threshold20_owner.py",
    "test_step5_threshold20.py",
)


def main() -> int:
    failures = 0
    count = 0
    for index, filename in enumerate(TEST_FILES):
        path = TESTS / filename
        spec = importlib.util.spec_from_file_location(f"step5_candidate_tests_{index}", path)
        if spec is None or spec.loader is None:
            print(f"FAIL cannot import {path}")
            failures += 1
            continue
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)
        for name, test in vars(module).items():
            if not name.startswith("test_") or not callable(test):
                continue
            count += 1
            try:
                test()
            except Exception:
                failures += 1
                print(f"FAIL {filename}::{name}")
                traceback.print_exc()
            else:
                print(f"PASS {filename}::{name}")
    print(f"OFFLINE_TESTS={count} FAILURES={failures}")
    return 1 if failures or count == 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
