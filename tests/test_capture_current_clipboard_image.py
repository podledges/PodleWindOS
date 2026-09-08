from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAPTURE_DIR = ROOT / "tools" / "clipboard-images"
ENTRY = CAPTURE_DIR / "Capture-CurrentClipboardImage.ps1"
CORE = CAPTURE_DIR / "Capture-CurrentClipboardImage.Core.psm1"
README = CAPTURE_DIR / "README.md"
PS_TEST = CAPTURE_DIR / "tests" / "Test-CaptureCurrentClipboardImage.ps1"


def _production_source() -> str:
    return ENTRY.read_text(encoding="utf-8") + "\n" + CORE.read_text(encoding="utf-8")


class CaptureCurrentClipboardImageContractTests(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for path in (ENTRY, CORE, README, PS_TEST):
            self.assertTrue(path.is_file(), f"missing {path.relative_to(ROOT)}")

    def test_call_shape_and_defaults(self) -> None:
        entry = ENTRY.read_text(encoding="utf-8")
        readme = README.read_text(encoding="utf-8")
        self.assertIn("-DestinationDirectory", entry)
        self.assertIn("PodlePaste\\staging", entry)
        self.assertIn("[Threading.ApartmentState]::STA", entry)
        self.assertIn("powershell.exe -NoProfile -STA -File", entry)
        self.assertIn("powershell.exe -NoProfile -STA -File", readme)
        self.assertIn("-DestinationDirectory", readme)
        self.assertIn("LOCALAPPDATA", readme)
        self.assertIn("PodlePaste\\staging", readme)

    def test_success_json_contract_keys(self) -> None:
        core = CORE.read_text(encoding="utf-8")
        self.assertIn('{"schema":1,"kind":"image","label":"Screenshot Pasted"', core)
        self.assertIn("$escapedPath", core)
        self.assertIn("$Sha256", core)
        self.assertNotIn("ConvertTo-Json", core)

        example = {
            "schema": 1,
            "kind": "image",
            "label": "Screenshot Pasted",
            "path": r"C:\Users\ayden\AppData\Local\PodlePaste\staging\paste-example.png",
            "sha256": "a" * 64,
        }
        encoded = json.dumps(example, separators=(",", ":"))
        self.assertEqual(encoded.count("\n"), 0)
        parsed = json.loads(encoded)
        self.assertEqual(parsed["schema"], 1)
        self.assertEqual(parsed["kind"], "image")
        self.assertEqual(parsed["label"], "Screenshot Pasted")

    def test_sequence_race_and_unique_names(self) -> None:
        core = CORE.read_text(encoding="utf-8")
        self.assertIn("$sequenceBefore = & $GetSequence", core)
        self.assertIn("$sequenceAfter = & $GetSequence", core)
        self.assertIn("clipboard changed during capture", core)
        self.assertIn("clipboard is not an image", core)
        self.assertIn("FileMode]::CreateNew", core)
        self.assertIn("[System.IO.File]::Move", core)
        self.assertRegex(core, r"paste-\{0\}-\{1\}\.png")
        self.assertNotIn("Get-ChildItem", core)

    def test_production_source_has_no_screenshots2_or_clipboard_mutation(self) -> None:
        production = _production_source()
        self.assertIsNone(re.search(r"(?i)screenshots2", production))
        self.assertIsNone(
            re.search(
                r"(?i)Clipboard\]\s*::\s*(Set|Clear)|Set-(Clipboard|ClipboardText)",
                production,
            )
        )
        self.assertIsNone(
            re.search(
                r"(?i)System\.Net|HttpClient|WebClient|Invoke-WebRequest|Invoke-RestMethod",
                production,
            )
        )
        self.assertNotIn("Get-ChildItem", production)

    def test_synthetic_tests_do_not_touch_live_clipboard(self) -> None:
        ps_test = PS_TEST.read_text(encoding="utf-8")
        self.assertNotIn("Clipboard]::GetImage", ps_test)
        self.assertNotIn("Clipboard]::ContainsImage", ps_test)
        self.assertNotIn("Clipboard]::Set", ps_test)
        self.assertNotIn("Clipboard]::Clear", ps_test)
        self.assertIn("New-Object System.Drawing.Bitmap", ps_test)
        self.assertIn("GetNewClosure", ps_test)

    def test_keeps_autosaver_and_on_demand_capture(self) -> None:
        names = {path.name for path in CAPTURE_DIR.iterdir() if path.is_file()}
        self.assertIn("ClipboardImageAutosave.ps1", names)
        self.assertIn("Start-ClipboardImageAutosave.ps1", names)
        self.assertIn("Stop-ClipboardImageAutosave.ps1", names)
        self.assertIn("Capture-CurrentClipboardImage.ps1", names)
        self.assertTrue(
            (CAPTURE_DIR / "Capture-CurrentClipboardImage.Core.psm1").is_file()
        )
        self.assertTrue((CAPTURE_DIR / "ClipboardImageAutosave.Core.psm1").is_file())


if __name__ == "__main__":
    unittest.main()
