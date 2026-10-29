"""Unexecuted acceptance candidates: GAME-WEB-MODULE-ENGINE-001.

Do not run without author approval. No third-party dependencies.
"""
import json
import tempfile
import unittest
from pathlib import Path

from prototypes import save_candidate as baseline
from prototypes import save_recovery_candidate as recovery


class SaveRecoveryCandidateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.primary = self.root / "world.json"
        self.backups = self.root / "archives"

    def write_valid(self, ticks=12):
        state = baseline.advance(baseline.new_game(), ticks)
        baseline.save_game(state, self.primary)
        return state

    def backup(self):
        return recovery.create_backup(self.primary, self.backups)

    def test_backup_keeps_exact_bytes_and_schema(self):
        state = self.write_valid()
        original = self.primary.read_bytes()
        item = self.backup()
        self.assertEqual(self.primary.read_bytes(), original)
        self.assertEqual((Path(item["path"]) / "save.json").read_bytes(), original)
        self.assertEqual(recovery.inspect_backup(item["path"])["status"], "valid")
        self.assertEqual(recovery.list_backups(self.primary, self.backups)[0]["free_clock"],
                         state["free_clock"])

    def test_missing_and_invalid_save_cannot_be_backed_up(self):
        self.assertEqual(recovery.inspect_save(self.primary)["status"], "missing")
        with self.assertRaises(recovery.RecoveryError):
            self.backup()
        for invalid in (b"not-json", b'{"version":0}', b'{"version":true}'):
            self.primary.write_bytes(invalid)
            self.assertEqual(recovery.inspect_save(self.primary)["status"], "corrupt")
            with self.assertRaises(recovery.RecoveryError):
                self.backup()

    def test_strict_corruption_detection(self):
        self.write_valid()
        payload = json.loads(self.primary.read_text(encoding="utf-8"))
        cases = [
            b'{"version":1,"version":1}',
            b'{"version":NaN}',
            b"\xff\xfe",
            b"x" * (recovery.MAX_SAVE_BYTES + 1),
        ]
        for raw in cases:
            with self.subTest(raw=raw[:40]):
                self.primary.write_bytes(raw)
                self.assertEqual(recovery.inspect_save(self.primary)["status"], "corrupt")
        self.primary.write_text(json.dumps(payload), encoding="utf-8")
        self.assertEqual(recovery.inspect_save(self.primary)["status"], "valid")

    def test_corrupt_backup_payload_blocks_restore(self):
        self.write_valid()
        snapshot = Path(self.backup()["path"])
        (snapshot / "save.json").write_bytes(b'{"modified":true}')
        original = self.primary.read_bytes()
        self.assertEqual(recovery.inspect_backup(snapshot)["status"], "corrupt")
        with self.assertRaises(recovery.RecoveryError):
            recovery.restore_backup(snapshot, self.primary)
        self.assertEqual(self.primary.read_bytes(), original)

    def test_manifest_tampering_blocks_restore(self):
        self.write_valid()
        snapshot = Path(self.backup()["path"])
        manifest_file = snapshot / "manifest.json"
        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
        manifest["free_clock"] += 1
        manifest_file.write_text(json.dumps(manifest), encoding="utf-8")
        self.assertEqual(recovery.inspect_backup(snapshot)["status"], "corrupt")
        with self.assertRaises(recovery.RecoveryError):
            recovery.restore_backup(snapshot, self.root / "other.json")
        self.assertFalse((self.root / "other.json").exists())

    def test_restore_missing_destination_exact_bytes(self):
        self.write_valid()
        original = self.primary.read_bytes()
        snapshot = self.backup()["path"]
        self.primary.unlink()
        result = recovery.restore_backup(snapshot, self.primary)
        self.assertEqual(result["status"], "restored")
        self.assertEqual(self.primary.read_bytes(), original)
        self.assertIsNone(result["quarantine_path"])

    def test_corrupt_destination_quarantined_before_restore(self):
        self.write_valid()
        original = self.primary.read_bytes()
        snapshot = self.backup()["path"]
        corrupt = b'{"interrupted"'
        self.primary.write_bytes(corrupt)
        result = recovery.restore_backup(snapshot, self.primary)
        self.assertEqual(self.primary.read_bytes(), original)
        quarantine = Path(result["quarantine_path"])
        self.assertTrue(quarantine.is_file())
        self.assertEqual(quarantine.read_bytes(), corrupt)

    def test_valid_save_needs_explicit_replace_and_rollback(self):
        self.write_valid(12)
        snapshot = self.backup()["path"]
        baseline.save_game(baseline.advance(baseline.new_game(), 20), self.primary)
        latest = self.primary.read_bytes()
        with self.assertRaises(recovery.RecoveryError):
            recovery.restore_backup(snapshot, self.primary)
        with self.assertRaises(recovery.RecoveryError):
            recovery.restore_backup(snapshot, self.primary, replace_valid=True)
        self.assertEqual(self.primary.read_bytes(), latest)
        done = recovery.restore_backup(
            snapshot, self.primary, replace_valid=True, allow_rollback=True,
            backup_dir=self.backups)
        self.assertEqual(done["free_clock"], 12)
        self.assertEqual(baseline.load_game(self.primary)["free_clock"], 12)
        self.assertEqual(
            (Path(done["previous_backup_path"]) / "save.json").read_bytes(),
            latest)

    def test_equal_clock_different_content_requires_replace(self):
        self.write_valid(12)
        snapshot = self.backup()["path"]
        state = baseline.enter_chapter(baseline.advance(baseline.new_game(), 12), "ch1")
        baseline.save_game(state, self.primary)
        with self.assertRaises(recovery.RecoveryError):
            recovery.restore_backup(snapshot, self.primary)
        result = recovery.restore_backup(
            snapshot, self.primary, replace_valid=True, backup_dir=self.backups)
        self.assertEqual(result["status"], "restored")
        self.assertEqual(baseline.load_game(self.primary)["mode"], "free")

    def test_identical_restoration_is_noop(self):
        self.write_valid()
        snapshot = self.backup()["path"]
        before = self.primary.read_bytes()
        outcome = recovery.restore_backup(snapshot, self.primary)
        self.assertEqual(outcome["status"], "unchanged")
        self.assertEqual(self.primary.read_bytes(), before)
        self.assertEqual(len(recovery.list_backups(self.primary, self.backups)), 1)

    def test_pending_snapshot_is_not_listed(self):
        self.write_valid()
        self.backup()
        (self.backups / ".pending-interrupted").mkdir()
        self.assertEqual(len(recovery.list_backups(self.primary, self.backups)), 1)

    def test_invalid_version_and_boolean_clock(self):
        self.write_valid()
        for patch in ({"version": 2}, {"free_clock": True},
                      {"mode": "unknown"}, {"free_clock": -1}):
            payload = baseline.new_game()
            payload.update(patch)
            self.primary.write_text(json.dumps(payload), encoding="utf-8")
            self.assertEqual(recovery.inspect_save(self.primary)["status"], "corrupt")

    def test_source_and_destination_symlinks_rejected(self):
        self.write_valid()
        snapshot = self.backup()["path"]
        alias = self.root / "alias.json"
        try:
            alias.symlink_to(self.primary)
        except (OSError, NotImplementedError):
            self.skipTest("symbolic links unavailable")
        with self.assertRaises(recovery.RecoveryError):
            recovery.create_backup(alias, self.backups)
        with self.assertRaises(recovery.RecoveryError):
            recovery.restore_backup(snapshot, alias)

    def test_backup_listing_reports_bad_snapshot(self):
        self.write_valid()
        folder = Path(self.backup()["path"])
        (folder / "manifest.json").unlink()
        results = recovery.list_backups(self.primary, self.backups)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["status"], "corrupt")


if __name__ == "__main__":
    unittest.main()
