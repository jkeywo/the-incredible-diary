"""Restore only tracked UTF-8 files unchanged except for CRLF/LF line endings.

Dry run: python tools/clean_line_endings.py
Apply:   python tools/clean_line_endings.py --apply

Compares against the index, not HEAD, so staged edits remain intact. Ignores
untracked files, deletions, conflicts, symlinks, binaries and substantive edits.
Git restore applies the repository's checkout rules from .gitattributes.
"""

import argparse
import os
from pathlib import Path
import subprocess


def git(root, *args, input_data=None):
    result = subprocess.run(
        ["git", "--literal-pathspecs", "-C", str(root), *args],
        input=input_data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout


def same_text(left, right):
    if b"\0" in left or b"\0" in right:
        return False
    try:
        left.decode("utf-8")
        right.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return left.replace(b"\r\n", b"\n") == right.replace(b"\r\n", b"\n")


def clean(root, apply=False):
    # ls-files -m includes stat-only dirtiness that porcelain diff can hide.
    modified = set(git(root, "ls-files", "-m", "-z").split(b"\0"))
    entries = git(root, "ls-files", "--stage", "-z").split(b"\0")
    candidates = []
    for entry in entries:
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, blob, stage = metadata.split()
        if raw_path not in modified or stage != b"0" or mode not in (b"100644", b"100755"):
            continue
        path = os.fsdecode(raw_path)
        target = root / path
        if target.is_symlink() or not target.is_file():
            continue
        indexed = git(root, "cat-file", "blob", blob.decode("ascii"))
        working = target.read_bytes()
        if same_text(indexed, working):
            candidates.append((path, working))
    if apply and candidates:
        for path, original in candidates:
            # Refuse to overwrite a concurrent edit after the comparison.
            if (root / path).read_bytes() != original:
                raise RuntimeError(f"File changed during cleanup: {path}")
        git(root, "restore", "--worktree", "--pathspec-from-file=-", "--pathspec-file-nul",
            input_data=b"".join(os.fsencode(path) + b"\0" for path, _ in candidates))
    for path, _ in candidates:
        print(f"{'Restored' if apply else 'Would restore'}: {path}")
    print(f"{len(candidates)} file(s) {'restored' if apply else 'eligible'}. Substantive edits preserved.")
    return len(candidates)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Restore eligible files; otherwise only list them")
    args = parser.parse_args()
    root = Path(os.fsdecode(git(Path.cwd(), "rev-parse", "--show-toplevel")).strip())
    clean(root, args.apply)


if __name__ == "__main__":
    main()
