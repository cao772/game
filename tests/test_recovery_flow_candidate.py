"""Future acceptance candidates for GAME-WEB-CONTINUE-ENGINE-003.

NOT_RUN; unittest code only. No test invocation is part of this delivery.
"""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prototypes import save_candidate as baseline
from prototypes import save_recovery_candidate as v1
from prototypes import recovery_flow_candidate as flow


class RecoveryFlowCandidateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.primary = self.root / "world.json"
        self.backups = self.root / "archives"
        self.output = self.root / "recovered"
        self.output.mkdir()

    def write_save(self, ticks=10):
        state = baseline.advance(baseline.new_game(), ticks)
        baseline.save_game(state, self.primary)
        return state

    def snapshot(self):
        return Path(v1.create_backup(self.primary, self.backups)["path"])

    def preview(self, snapshot):
        return flow.preview_non_overwrite(snapshot, self.primary, self.output)

    def test_readonly_preview_does_not_create_or_change_files(self):
        self.write_save()
        snapshot = self.snapshot()
        source_before = self.primary.read_bytes()
        manifest_before = (snapshot / "manifest.json").read_bytes()
        payload_before = (snapshot / "save.json").read_bytes()
        listing_before = list(self.output.iterdir())
        planned = self.preview(snapshot)
        self.assertTrue(planned["ready"])
        self.assertEqual(planned["operation"], "new_directory_only")
        self.assertEqual(planned["backup"]["category"], "none")
        self.assertEqual(planned["original"]["category"], "none")
        self.assertEqual(self.primary.read_bytes(), source_before)
        self.assertEqual((snapshot / "manifest.json").read_bytes(), manifest_before)
        self.assertEqual((snapshot / "save.json").read_bytes(), payload_before)
        self.assertEqual(list(self.output.iterdir()), listing_before)
        self.assertEqual(planned, self.preview(snapshot))

    def test_nonoverwrite_recovery_retains_original_and_unrelated_files(self):
        self.write_save(10)
        snapshot = self.snapshot()
        original = self.primary.read_bytes()
        unrelated = self.output / "notes.txt"
        unrelated.write_text("keep", encoding="utf-8")
        result = flow.recover_non_overwrite(self.preview(snapshot))
        recovered_dir = Path(result["recovery_dir"])
        self.assertTrue(recovered_dir.is_dir())
        self.assertEqual((recovered_dir / "save.json").read_bytes(), original)
        self.assertEqual(self.primary.read_bytes(), original)
        self.assertEqual(unrelated.read_text(encoding="utf-8"), "keep")
        self.assertEqual(flow.inspect_recovery(recovered_dir)["status"], "active")
        self.assertFalse(result["original_modified"])
        receipt = json.loads((recovered_dir / "receipt.json").read_text("utf-8"))
        self.assertEqual(receipt["payload_sha256"], result["payload_sha256"])
        self.assertFalse(receipt["original_modified"])

    def test_two_restores_never_reuse_or_overwrite_same_destination(self):
        self.write_save()
        snapshot = self.snapshot()
        planned = self.preview(snapshot)
        first = flow.recover_non_overwrite(planned)
        second = flow.recover_non_overwrite(planned)
        self.assertNotEqual(first["recovery_dir"], second["recovery_dir"])
        self.assertEqual(
            (Path(first["recovery_dir"]) / "save.json").read_bytes(),
            (Path(second["recovery_dir"]) / "save.json").read_bytes())

    def test_preview_warns_when_archive_clock_is_older(self):
        self.write_save(10)
        snapshot = self.snapshot()
        baseline.save_game(
            baseline.advance(baseline.new_game(), 25), self.primary)
        later = self.primary.read_bytes()
        planned = self.preview(snapshot)
        self.assertIn("candidate_older_than_original", "".join(planned["warnings"]))
        self.assertTrue(planned["ready"])
        recovered = flow.recover_non_overwrite(planned)
        self.assertEqual(baseline.load_game(Path(recovered["recovery_dir"]) /
                                            "save.json")["free_clock"], 10)
        self.assertEqual(self.primary.read_bytes(), later)

    def test_corrupt_original_is_classified_and_not_overwritten(self):
        self.write_save()
        snapshot = self.snapshot()
        corrupt_bytes = b'{"version":1,'
        self.primary.write_bytes(corrupt_bytes)
        planned = self.preview(snapshot)
        self.assertTrue(planned["ready"])
        self.assertEqual(planned["original"]["category"], "invalid_json")
        result = flow.recover_non_overwrite(planned)
        self.assertEqual(self.primary.read_bytes(), corrupt_bytes)
        self.assertEqual(flow.inspect_recovery(result["recovery_dir"])["status"],
                         "active")

    def test_missing_original_only_creates_separate_recovered_copy(self):
        self.write_save()
        snapshot = self.snapshot()
        self.primary.unlink()
        planned = self.preview(snapshot)
        self.assertEqual(planned["original"]["status"], "missing")
        self.assertTrue(planned["ready"])
        result = flow.recover_non_overwrite(planned)
        self.assertFalse(self.primary.exists())
        self.assertTrue((Path(result["recovery_dir"]) / "save.json").exists())

    def test_classify_specific_invalid_save_forms(self):
        self.write_save()
        samples = (
            (b"\xff\xfe", "invalid_utf8"),
            (b"{bad json", "invalid_json"),
            (b'{"version":1,"version":1}', "duplicate_json_key"),
            (b'{"version":NaN}', "nonfinite_json_number"),
            (b'{"version":true}', "version_type_invalid"),
            (b'{"version":2}', "unsupported_version"),
            (b'{"version":1,"mode":"unsupported"}', "unknown_mode"),
        )
        for payload, code in samples:
            with self.subTest(code=code):
                self.primary.write_bytes(payload)
                info = flow.classify_save(self.primary)
                self.assertEqual(info["status"], "corrupt")
                self.assertEqual(info["category"], code)

    def test_negative_boolean_chapter_and_free_clocks(self):
        for patch in (
            {"free_clock": -1},
            {"free_clock": True},
            {"history": {"active_chapter": None, "entry_free_clock": None,
                         "chapter_clocks": {"ch": True}}},
            {"history": {"active_chapter": None, "entry_free_clock": None,
                         "chapter_clocks": {"ch": -1}}},
        ):
            state = baseline.new_game()
            state.update(patch)
            self.primary.write_text(json.dumps(state), encoding="utf-8")
            self.assertEqual(flow.classify_save(self.primary)["category"],
                             "invalid_clock")

    def test_oversized_original_refuses_preview_without_fingerprint(self):
        self.write_save()
        snapshot = self.snapshot()
        self.primary.write_bytes(b"x" * (v1.MAX_SAVE_BYTES + 1))
        planned = self.preview(snapshot)
        self.assertFalse(planned["ready"])
        self.assertEqual(planned["original"]["category"], "oversized")
        with self.assertRaises(flow.RecoveryFlowError):
            flow.recover_non_overwrite(planned)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_missing_output_root_is_never_created_implicitly(self):
        self.write_save()
        snapshot = self.snapshot()
        unknown = self.root / "does-not-exist"
        planned = flow.preview_non_overwrite(snapshot, self.primary, unknown)
        self.assertFalse(planned["ready"])
        with self.assertRaises(flow.RecoveryFlowError):
            flow.recover_non_overwrite(planned)
        self.assertFalse(unknown.exists())

    def test_bad_backup_payload_and_manifest_refuse_preview(self):
        self.write_save()
        snapshot = self.snapshot()
        (snapshot / "save.json").write_bytes(b"tampered")
        planned = self.preview(snapshot)
        self.assertFalse(planned["ready"])
        self.assertEqual(planned["backup"]["status"], "corrupt")
        with self.assertRaises(flow.RecoveryFlowError):
            flow.recover_non_overwrite(planned)

    def test_bad_manifest_detected_as_classified_corruption(self):
        self.write_save()
        snapshot = self.snapshot()
        (snapshot / "manifest.json").unlink()
        info = flow.classify_backup(snapshot)
        self.assertEqual(info["category"], "manifest_missing")
        self.assertFalse(self.preview(snapshot)["ready"])

    def test_original_changed_after_preview_refuses_and_keeps_original(self):
        self.write_save(10)
        snapshot = self.snapshot()
        planned = self.preview(snapshot)
        baseline.save_game(baseline.advance(baseline.new_game(), 30),
                           self.primary)
        current = self.primary.read_bytes()
        with self.assertRaises(flow.RecoveryFlowError):
            flow.recover_non_overwrite(planned)
        self.assertEqual(self.primary.read_bytes(), current)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_manifest_changed_after_preview_refuses(self):
        self.write_save()
        snapshot = self.snapshot()
        planned = self.preview(snapshot)
        manifest_path = snapshot / "manifest.json"
        manifest = json.loads(manifest_path.read_text("utf-8"))
        manifest["created_utc"] = "different"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaises(flow.RecoveryFlowError):
            flow.recover_non_overwrite(planned)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_modified_preview_dict_refuses(self):
        self.write_save()
        snapshot = self.snapshot()
        planned = self.preview(snapshot)
        planned["operation"] = "replace_original"
        with self.assertRaises(flow.RecoveryFlowError):
            flow.recover_non_overwrite(planned)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_rollback_renames_and_keeps_original_and_evidence(self):
        self.write_save()
        snapshot = self.snapshot()
        source = self.primary.read_bytes()
        result = flow.recover_non_overwrite(self.preview(snapshot))
        active = Path(result["recovery_dir"])
        outcome = flow.rollback_non_overwrite(active)
        retained = Path(outcome["retained_path"])
        self.assertFalse(active.exists())
        self.assertTrue(retained.is_dir())
        self.assertEqual((retained / "save.json").read_bytes(), source)
        self.assertEqual(self.primary.read_bytes(), source)
        self.assertEqual(flow.inspect_recovery(retained)["status"], "rolled_back")
        with self.assertRaises(flow.RecoveryFlowError):
            flow.rollback_non_overwrite(retained)
        with self.assertRaises(flow.RecoveryFlowError):
            flow.rollback_non_overwrite(active)

    def test_rollback_of_modified_recovered_copy_refuses(self):
        self.write_save()
        snapshot = self.snapshot()
        result = flow.recover_non_overwrite(self.preview(snapshot))
        recovered = Path(result["recovery_dir"])
        (recovered / "save.json").write_bytes(b"changed")
        self.assertEqual(flow.inspect_recovery(recovered)["status"], "corrupt")
        with self.assertRaises(flow.RecoveryFlowError):
            flow.rollback_non_overwrite(recovered)
        self.assertTrue(recovered.exists())

    def test_symlinks_refused_for_original_backup_or_output_root(self):
        self.write_save()
        snapshot = self.snapshot()
        alias = self.root / "alias"
        try:
            alias.symlink_to(self.primary)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unsupported by filesystem")
        bad_original = flow.preview_non_overwrite(snapshot, alias, self.output)
        self.assertFalse(bad_original["ready"])
        self.assertEqual(bad_original["original"]["category"], "symlink")
        alias.unlink()
        alias.symlink_to(self.output, target_is_directory=True)
        self.assertFalse(flow.preview_non_overwrite(snapshot, self.primary,
                                                   alias)["ready"])

    def test_permission_error_before_temp_create_keeps_original(self):
        self.write_save()
        snapshot = self.snapshot()
        planned = self.preview(snapshot)
        current = self.primary.read_bytes()
        with patch.object(flow.tempfile, "mkdtemp",
                          side_effect=PermissionError("denied")):
            with self.assertRaises(flow.RecoveryFlowError):
                flow.recover_non_overwrite(planned)
        self.assertEqual(self.primary.read_bytes(), current)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_rename_failure_keeps_original_and_cleans_pending(self):
        self.write_save()
        snapshot = self.snapshot()
        planned = self.preview(snapshot)
        current = self.primary.read_bytes()
        with patch.object(flow.os, "rename", side_effect=OSError("injected")):
            with self.assertRaises(flow.RecoveryFlowError):
                flow.recover_non_overwrite(planned)
        self.assertEqual(self.primary.read_bytes(), current)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_rollback_rename_failure_keeps_active_recovery(self):
        self.write_save()
        snapshot = self.snapshot()
        result = flow.recover_non_overwrite(self.preview(snapshot))
        active = Path(result["recovery_dir"])
        with patch.object(flow.os, "rename", side_effect=PermissionError("no")):
            with self.assertRaises(flow.RecoveryFlowError):
                flow.rollback_non_overwrite(active)
        self.assertEqual(flow.inspect_recovery(active)["status"], "active")

    def test_classify_permission_failure_separately(self):
        self.write_save()
        with patch.object(flow.prior, "_read_limited",
                          side_effect=PermissionError("denied")):
            classification = flow.classify_save(self.primary)
        self.assertEqual(classification["status"], "inaccessible")
        self.assertEqual(classification["category"], "permission_denied")


if __name__ == "__main__":
    unittest.main()
