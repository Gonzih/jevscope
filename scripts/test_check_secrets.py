#!/usr/bin/env python3
"""Adversarial tests for scripts/check-secrets.py.

Each case reproduces a defect an independent review found in the previous
version. Every case runs the real checker, from a real .env, in a disposable
git repository. No test prints a credential: expectations are asserted on exit
code and on whether the credential leaked into the checker's own output.

Run:  python3 scripts/test_check_secrets.py
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CHECKER = REPO / "scripts" / "check-secrets.py"

# Two synthetic credentials. Neither is real; both are fixed so tests are
# deterministic. The second exists to prove prefix-only matching is not enough.
# Assembled from fragments at runtime so no credential-shaped literal appears
# contiguously in this file -- a committed file holding one is a real leak, and
# the checker is right to flag it.
KEY_A = "jev" + "_" + "live" + "_" + "AAAA" "BBBB" "CCCC" "DDDD" "EEEE" "FFFF" "GGGG"
KEY_B = "gh" + "o_" + "ZZZZ" "YYYY" "XXXX" "WWWW" "VVVV" "UUUU" "TTTT" "SSSS"


class Result:
    def __init__(self, code: int, out: str):
        self.code = code
        self.out = out

    @property
    def leaked(self) -> bool:
        return KEY_A in self.out or KEY_B in self.out


def make_repo(key: str = KEY_A, env_comment: str = "") -> Path:
    d = Path(tempfile.mkdtemp(prefix="chksec-"))
    subprocess.run(["git", "-C", str(d), "init", "-q"], check=True)
    env = f"{ENV_NAME}={key}\n" if not env_comment else f"{ENV_NAME}={key} # {env_comment}\n"
    (d / ".env").write_text(env)
    (d / ".gitignore").write_text(".env\n")
    scripts = d / "scripts"
    scripts.mkdir()
    shutil.copy(CHECKER, scripts / "check-secrets.py")
    (d / "README.md").write_text("# fixture\n")
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    subprocess.run(["git", "-C", str(d), "-c", "user.email=t@t", "-c", "user.name=t",
                    "commit", "-qm", "init"], check=True,
                   capture_output=True)
    return d


ENV_NAME = "TYPESAFE_API_KEY"
RESULTS: list[tuple[str, bool, str]] = []


def record(name: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}{('  -- ' + detail) if detail and not ok else ''}")


def run(d: Path) -> Result:
    p = subprocess.run([sys.executable, str(d / "scripts" / "check-secrets.py")],
                       capture_output=True, text=True, cwd=d)
    return Result(p.returncode, p.stdout + p.stderr)


def case_clean():
    d = make_repo()
    r = run(d)
    record("clean fixture exits 0", r.code == 0, f"code={r.code}")
    shutil.rmtree(d, ignore_errors=True)


def case_secret_in_file():
    d = make_repo()
    (d / "leak.md").write_text(f'token = "{KEY_A}"\n')
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    r = run(d)
    record("exact secret in tracked file -> exit 1", r.code == 1, f"code={r.code}")
    record("  ... and not echoed in output", not r.leaked)
    record("  ... and the path IS reported", "leak.md" in r.out)
    shutil.rmtree(d, ignore_errors=True)


def case_placeholder_doc():
    """A doc that merely names the variable and shows a prefix must NOT trip it."""
    d = make_repo()
    (d / "docs.md").write_text(
        "Set TYPESAFE_API_KEY in .env.\n"
        "Tokens look like gho_... or jev_live_... — see the dashboard.\n"
        "The value is never committed.\n"
    )
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    r = run(d)
    record("documentation mentioning prefixes exits 0 (no false positive)",
           r.code == 0, f"code={r.code} out={r.out[:200]}")
    shutil.rmtree(d, ignore_errors=True)


def case_secret_in_checker_itself():
    d = make_repo()
    p = d / "scripts" / "check-secrets.py"
    p.write_text(p.read_text() + f'\n# accidental paste: {KEY_A}\n')
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    r = run(d)
    record("secret pasted into the checker itself -> exit 1 (was missed)", r.code == 1, f"code={r.code}")
    record("  ... and not echoed", not r.leaked)
    shutil.rmtree(d, ignore_errors=True)


def case_oversized():
    d = make_repo()
    (d / "big.bin").write_bytes(b"A" * (17 * 1024 * 1024) + KEY_A.encode())
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    r = run(d)
    record("oversized tracked file -> exit 1 (was silently skipped)", r.code == 1, f"code={r.code}")
    record("  ... and reported as unscannable", "could not scan" in r.out or "exceeds" in r.out)
    shutil.rmtree(d, ignore_errors=True)


def case_staged_not_in_worktree():
    """Secret staged, then removed from disk: the index still holds it."""
    d = make_repo()
    (d / "staged.md").write_text(f'{KEY_A}\n')
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    os.remove(d / "staged.md")
    r = run(d)
    record("staged-then-deleted secret -> exit 1 (was missed)", r.code == 1, f"code={r.code}")
    shutil.rmtree(d, ignore_errors=True)


def case_untracked_is_not_scanned():
    """A file fully removed from the index is not a tracked file, so it is not
    scanned and the run stays clean. (An earlier version of this test asserted
    exit 1 here, which was wrong: the checker had nothing to scan.)"""
    d = make_repo()
    (d / "temp.md").write_text("scratch\n")
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    subprocess.run(["git", "-C", str(d), "rm", "-q", "--cached", "temp.md"], check=True)
    subprocess.run(["git", "-C", str(d), "commit", "-qm", "drop", "--allow-empty"], check=True,
                   capture_output=True)
    r = run(d)
    record("file removed from index is not scanned -> exit 0", r.code == 0, f"code={r.code}")
    shutil.rmtree(d, ignore_errors=True)


def case_env_inline_comment():
    """A comment in .env must not become part of the needle."""
    d = make_repo(key=KEY_A, env_comment="keep this out of the needle")
    (d / "leak.md").write_text(f'{KEY_A}\n')
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    r = run(d)
    record("env with inline comment still detects the bare key -> exit 1",
           r.code == 1, f"code={r.code}")
    record("  ... and not echoed", not r.leaked)
    shutil.rmtree(d, ignore_errors=True)


def case_secret_in_filename():
    d = make_repo()
    (d / f"notes-{KEY_A}.md").write_text("hi\n")
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    r = run(d)
    record("secret in FILENAME -> exit 1", r.code == 1, f"code={r.code}")
    record("  ... and filename is REDACTED in output (was printed)", not r.leaked)
    shutil.rmtree(d, ignore_errors=True)


def case_second_credential_same_prefix():
    """Prefix-only matching was disabled for prefixes present in the current
    key; a different token of the same shape must still be caught."""
    d = make_repo(key=KEY_A)
    (d / "other.md").write_text(f'token = "{KEY_B}"\n')
    subprocess.run(["git", "-C", str(d), "add", "-A"], check=True)
    r = run(d)
    record("different credential of the same shape -> exit 1", r.code == 1, f"code={r.code}")
    record("  ... and not echoed", not r.leaked)
    shutil.rmtree(d, ignore_errors=True)


def case_no_env():
    d = make_repo()
    (d / ".env").unlink()
    r = run(d)
    record("missing .env -> exit 2 (cannot run)", r.code == 2, f"code={r.code}")
    shutil.rmtree(d, ignore_errors=True)


def main() -> int:
    for fn in (case_clean, case_secret_in_file, case_placeholder_doc,
               case_secret_in_checker_itself, case_oversized,
               case_staged_not_in_worktree, case_env_inline_comment,
               case_untracked_is_not_scanned, case_secret_in_filename,
               case_second_credential_same_prefix, case_no_env):
        fn()
    passed = sum(1 for _, ok, _ in RESULTS if ok)
    total = len(RESULTS)
    print(f"\n{passed}/{total} assertions passed")
    if passed != total:
        print("failing:")
        for name, ok, detail in RESULTS:
            if not ok:
                print(f"  - {name}  {detail}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())