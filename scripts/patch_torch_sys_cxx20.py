#!/usr/bin/env python3
"""Patch torch-sys 0.24.0's C++ type alias for C++20 compatibility.

In C++20, `module` is a keyword. torch-sys 0.24.0 uses it as a typedef
name in torch_api.h and torch_api.cpp. SGLang's PyTorch 2.12+ build
intentionally uses C++20, so rename the identifier consistently.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    cargo_home = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else Path.home() / ".cargo"
    registry = cargo_home / "registry" / "src"
    candidates = sorted(registry.glob("*/torch-sys-0.24.0/libtch"))

    if not candidates:
        print(
            f"[TORCH-SYS-PATCH] torch-sys 0.24.0 not found under {registry}",
            file=sys.stderr,
        )
        return 1

    total = 0
    for libtch in candidates:
        for filename in ("torch_api.h", "torch_api.cpp"):
            path = libtch / filename
            if not path.is_file():
                print(f"[TORCH-SYS-PATCH] Missing expected file: {path}", file=sys.stderr)
                return 1

            source = path.read_text(encoding="utf-8")
            updated, count = re.subn(r"\bmodule\b", "torch_module", source)

            if count:
                path.write_text(updated, encoding="utf-8")
                print(f"[TORCH-SYS-PATCH] {path}: renamed {count} identifier(s)")
                total += count
            elif "torch_module" not in source:
                print(
                    f"[TORCH-SYS-PATCH] Unexpected torch-sys source layout: {path}",
                    file=sys.stderr,
                )
                return 1

            if re.search(r"\bmodule\b", path.read_text(encoding="utf-8")):
                print(f"[TORCH-SYS-PATCH] Unpatched 'module' identifier remains in {path}", file=sys.stderr)
                return 1

    print(f"[TORCH-SYS-PATCH] Compatibility patch verified; {total} new replacement(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
