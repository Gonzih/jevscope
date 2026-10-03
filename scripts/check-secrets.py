#!/usr/bin/env python3
"""Check that no tracked file contains the TypeSafe API key.

Design constraints, each from an observed failure:
  * The configured key is compared as BYTES read from .env in-process. It is
    never placed in argv, never printed, and never written to output.
  * Scanned content is what git has STAGED (the index blob), not the working
    copy, so a staged-but-uncommitted leak is caught.
  * The scanner scans ITSELF. Exempting its own source would let a key pasted
    into a comment there through silently.
  * An unreadable, oversized, or missing tracked file is a FAILURE, never a
    silent skip. A checker that skips what it cannot read is worse than none.
  * Filenames are redacted before printing: a key in a *path* is still a leak.
  * Fragment matching requires credential SHAPE (prefix + length), so ordinary
    documentation mentioning an OAuth prefix is not a false positive.

Exit 0 = clean. Exit 1 = leak or unscannable input. Exit 2 = cannot run.
"""
from __future__ import annotations

import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

ENV_NAME = "TYPESAFE_API_KEY"
# Credential shapes: prefix + enough following characters to be a real token,
# not a documentation reference. Longest first so the more specific wins.
SHAPES = (
    re.compile(rb"gho_[A-Za-z0-9]{16,}"),
    re.compile(rb"ghp_[A-Za-z0-9]{16,}"),
    re.compile(rb"ghs_[A-Za-z0-9]{16,}"),
    re.compile(rb"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(rb"jev_live_[A-Za-z0-9_-]{8,}"),
    re.compile(rb"jev_test_[A-Za-z0-9_-]{8,}"),
)
MAX_BYTES = 16 * 1024 * 1024
REDACT = b"<REDACTED>"


def fail(msg: str) -> None:
    print(f"check-secrets: {msg}", file=sys.stderr)
    raise SystemExit(2)


def parse_env(path: Path) -> bytes:
    """Minimal, strict dotenv read: KEY=value, optional quotes, no inline
    comment handling (a '#' inside a quoted value is data, not a comment)."""
    if not path.is_file():
        fail(f"{path.name} not found; copy .env.example to .env")
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, val = line.partition("=")
        if not sep or key.strip() != ENV_NAME:
            continue
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        if not val:
            fail(f"{ENV_NAME} is empty in {path.name}")
        return val.encode()
    fail(f"{ENV_NAME} not found in {path.name}")


def index_paths(repo: Path) -> list[str]:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "ls-files", "-z"],
            capture_output=True, check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        fail("`git ls-files` failed; run this from inside the repository")
    return [p.decode("utf-8", "surrogateescape") for p in out.split(b"\0") if p]


def index_bytes(repo: Path, rel: str) -> bytes:
    """Content as staged in the git index, which is what would be committed."""
    proc = subprocess.run(
        ["git", "-C", str(repo), "show", f":{rel}"],
        capture_output=True,
    )
    if proc.returncode != 0:
        raise OSError(f"cannot read index blob for {rel}: {proc.stderr.decode(errors='replace').strip()}")
    return proc.stdout


def redact(data: bytes, needles: tuple[bytes, ...]) -> bytes:
    out = data
    for n in needles:
        if n:
            out = out.replace(n, REDACT)
    return out


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    secret = parse_env(repo / ".env")
    # Shape patterns are matched as regexes; the exact key is matched literally.
    needles = (secret,)
    all_needles = needles

    leaks: list[tuple[str, str]] = []   # (path, reason)
    unscannable: list[str] = []
    scanned = 0

    for rel in index_paths(repo):
        try:
            data = index_bytes(repo, rel)
        except OSError as exc:
            unscannable.append(f"{rel} ({exc})")
            continue
        if len(data) > MAX_BYTES:
            unscannable.append(f"{rel} (exceeds {MAX_BYTES} bytes; refusing to skip)")
            continue
        scanned += 1

        reasons = []
        for n in all_needles:
            if n and n in data:
                reasons.append("contains the configured API key")
        for pat in SHAPES:
            if pat.search(data):
                reasons.append(f"matches credential shape {pat.pattern.decode()}")
        # The path itself is part of the published surface.
        if any(n and n in rel.encode() for n in all_needles):
            reasons.append("API key appears in the FILENAME")
        for pat in SHAPES:
            if pat.search(rel.encode()):
                reasons.append("credential shape in the FILENAME")

        if reasons:
            leaks.append((rel, "; ".join(sorted(set(reasons)))))

    safe_print = lambda s: print(  # noqa: E731
        f"check-secrets: {redact(s.encode(), all_needles).decode(errors='replace')}"
    )
    safe_print(f"scanned {scanned} tracked file(s) (from the git index)")

    if unscannable:
        print("check-secrets: FAIL — could not scan:")
        for item in unscannable:
            safe_print(f"  {item}")
        print("check-secrets: refusing to pass with unscanned input.")
    if leaks:
        print(f"check-secrets: FAIL — {len(leaks)} file(s) contain credential material:")
        for rel, reason in leaks:
            safe_print(f"  {rel}: {reason}")
        print("check-secrets: remove the value and rotate the key if it was committed.")

    if unscannable or leaks:
        return 1
    print("check-secrets: OK — 0 files contain credential material")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())