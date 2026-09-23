"""Exercise the packaged T14 DTB migration without accessing the host's /boot."""

import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
INSTALLER = ROOT / "builder/hardware/hp-t14/t14-bluetooth-package/install-dtb"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


class T14RadioPackageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.target = root / "boot" / "t14.dtb"
        self.payload = root / "package" / "t14.dtb"
        self.target.parent.mkdir()
        self.payload.parent.mkdir()
        self.bin_dir = root / "bin"
        self.bin_dir.mkdir()
        mountpoint = self.bin_dir / "mountpoint"
        mountpoint.write_text('#!/bin/sh\n[ "$T14_TEST_MOUNTED" = 1 ]\n')
        mountpoint.chmod(0o755)

        self.base = b"kernel base DTB"
        self.old = b"shipped Bluetooth DTB"
        self.candidate = b"radio candidate DTB"
        script = INSTALLER.read_text()
        script = re.sub(r"(?m)^board_dtb=.*$", f"board_dtb={self.target}", script)
        script = re.sub(r"(?m)^trial_dtb=.*$", f"trial_dtb={self.payload}", script)
        for name, data in (("base_sha", self.base), ("old_sha", self.old),
                           ("candidate_sha", self.candidate)):
            script = re.sub(rf"(?m)^{name}=.*$", f"{name}={sha256(data)}", script)
        self.installer = root / "install-dtb"
        self.installer.write_text(script)
        self.installer.chmod(0o755)
        self.payload.write_bytes(self.candidate)
        self.env = dict(os.environ, PATH=f"{self.bin_dir}:{os.environ['PATH']}",
                        T14_TEST_MOUNTED="1")

    def run_installer(self):
        return subprocess.run([str(self.installer)], env=self.env, text=True,
                              capture_output=True, check=False)

    def test_known_trees_migrate_and_repeat_is_noop(self):
        for previous in (self.base, self.old):
            with self.subTest(previous=previous):
                self.target.write_bytes(previous)
                result = self.run_installer()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.target.read_bytes(), self.candidate)
                self.assertIn("installed", result.stdout)
                repeat = self.run_installer()
                self.assertEqual(repeat.returncode, 0, repeat.stderr)
                self.assertEqual(repeat.stdout, "")
                self.assertEqual(self.target.read_bytes(), self.candidate)
                self.assertEqual(list(self.target.parent.glob("*.omarchy-candidate.*")), [])

    def test_unknown_tree_is_untouched(self):
        self.target.write_bytes(b"future kernel DTB")
        result = self.run_installer()
        self.assertEqual(result.returncode, 0)
        self.assertIn("unknown kernel tree", result.stderr)
        self.assertEqual(self.target.read_bytes(), b"future kernel DTB")

    def test_corrupt_payload_fails_without_touching_target(self):
        self.target.write_bytes(self.old)
        self.payload.write_bytes(b"corrupt")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("payload hash mismatch", result.stderr)
        self.assertEqual(self.target.read_bytes(), self.old)

    def test_missing_mount_or_target_fails(self):
        self.target.write_bytes(self.base)
        self.env["T14_TEST_MOUNTED"] = "0"
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not mounted", result.stderr)
        self.assertEqual(self.target.read_bytes(), self.base)
        self.env["T14_TEST_MOUNTED"] = "1"
        self.target.unlink()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing", result.stderr)
        self.assertFalse(self.target.exists())


if __name__ == "__main__":
    unittest.main()
