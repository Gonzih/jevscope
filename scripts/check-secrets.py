#!/usr/bin/env python3
"""Check that no tracked file contains the TypeSafe API key.

Never prints the secret and never places it in a command-line argument:
the key is read from .env in-process and compared as bytes. Only file
paths and counts are printed.

Exit 0 = clean. Exit 1 = leak found. Exit 2 = cannot run (no .env / no git).
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ENV_NAME = "TYPESAFE_API_KEY"
# Literal credential shapes. The variable NAME is not a secret and must not be
# matched here, or every file that documents the variable trips the check.
FRAGMENTS = ("gho_", "jev_live_", "jev_test_")
MAX_BYTES = 8 * 1024 * 1024

def fail(msg: str) -> None:
    print(f"check-secrets: {msg}", file=sys.stderr)
    raise SystemExit(2)


def read_secret(env: Path) -> bytes:
    if not env.is_file():
        fail(f"{env} not found; copy .env.example to .env")
    for line in env.read_text(errors="replace").splitlines():
        key, sep, val = line.partition("=")
        if sep and key.strip() == ENV_NAME:
            val = val.strip().strip("'\"")
            if not val:
                fail(f"{ENV_NAME} is empty in {env}")
            return val.encode()
    fail(f"{ENV_NAME} not found in {env}")


def tracked_files(repo: Path) -> list[Path]:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "ls-files", "-z"],
            capture_output=True, check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        fail("`git ls-files` failed; run this from inside the repository")
    return [repo / p.decode() for p in out.split(b"\0") if p]


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    secret = read_secret(repo / ".env")
    needles = [secret] + [f.encode() for f in FRAGMENTS if f.encode() not in secret]

    leaks: list[str] = []
    scanned = 0
    for path in tracked_files(repo):
        # Skip this file: it necessarily contains the very credential shapes
        # it searches for, so scanning it would always fail.
        if path.resolve() == Path(__file__).resolve():
            continue
        try:
            if path.stat().st_size > MAX_BYTES:
                continue
            data = path.read_bytes()
        except OSError:
            continue
        scanned += 1
        if any(n in data for n in needles):
            leaks.append(str(path.relative_to(repo)))

    print(f"check-secrets: scanned {scanned} tracked file(s)")
    if leaks:
        print(f"check-secrets: FAIL — {len(leaks)} file(s) contain credential material:")
        for name in leaks:
            print(f"  {name}")
        print("check-secrets: remove the value and rotate the key if it was committed.")
        return 1
    print("check-secrets: OK — 0 files contain the API key")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())