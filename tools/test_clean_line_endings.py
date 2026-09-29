"""Safety checks using an isolated temporary repository, never the project index."""
import contextlib
import io
from pathlib import Path
import tempfile
import unittest

from clean_line_endings import clean, git, same_text


class CleanupTests(unittest.TestCase):
    def test_only_line_endings_are_ignored(self):
        self.assertTrue(same_text(b"a\r\nb\n", b"a\nb\n"))
        for other in (b"a \nb\n", b"a\nb", b"a\nb\n\n", b"a\rb\n"):
            self.assertFalse(same_text(b"a\nb\n", other))
        self.assertFalse(same_text(b"a\0\r\n", b"a\0\n"))

    def test_restore_preserves_index_and_real_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            git(root, "init")
            git(root, "config", "core.autocrlf", "false")
            (root / ".gitattributes").write_bytes(b"* text=auto eol=lf\n")
            for name in ("eol.txt", "real.txt", "staged.txt", "deleted.txt", "literal[1].txt"):
                (root / name).write_bytes(b"original\n")
            git(root, "add", ".")
            (root / "staged.txt").write_bytes(b"staged change\n")
            git(root, "add", "staged.txt")
            index_before = git(root, "ls-files", "--stage", "-z")
            (root / "eol.txt").write_bytes(b"original\r\n")
            (root / "literal[1].txt").write_bytes(b"original\r\n")
            (root / "staged.txt").write_bytes(b"staged change\r\n")
            (root / "real.txt").write_bytes(b"real change\r\n")
            (root / "untracked.txt").write_bytes(b"original\r\n")
            (root / "deleted.txt").unlink()
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(clean(root), 3)
                self.assertEqual((root / "eol.txt").read_bytes(), b"original\r\n")
                self.assertEqual(clean(root, apply=True), 3)
                self.assertEqual(clean(root), 0)
            self.assertEqual(git(root, "ls-files", "--stage", "-z"), index_before)
            self.assertEqual((root / "eol.txt").read_bytes(), b"original\n")
            self.assertEqual((root / "literal[1].txt").read_bytes(), b"original\n")
            self.assertEqual((root / "staged.txt").read_bytes(), b"staged change\n")
            self.assertEqual((root / "real.txt").read_bytes(), b"real change\r\n")
            self.assertEqual((root / "untracked.txt").read_bytes(), b"original\r\n")
            self.assertFalse((root / "deleted.txt").exists())


if __name__ == "__main__":
    unittest.main()
