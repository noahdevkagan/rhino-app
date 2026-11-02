import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import merge_corrections as m  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def pair(heard, corrected, installs=3, languages="en"):
    return {"heard": heard, "corrected": corrected, "installs": installs, "languages": languages, "engines": "whisper"}


class MergeTests(unittest.TestCase):
    def run_merge(self, pairs, entries=()):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "s.json").write_text(json.dumps({"generatedAt": "2026-11-02", "pairs": pairs}))
            (d / "b.json").write_text(json.dumps({"version": 1, "about": "x", "entries": list(entries)}))
            m.main(["--summary", str(d / "s.json"), "--bundle", str(d / "b.json"), "--report", str(d / "r.md")])
            return json.loads((d / "b.json").read_text()), (d / "r.md").read_text()

    def test_adds_frequent_pairs_sorted_and_keeps_metadata(self):
        bundle, report = self.run_merge([pair("git hub", "GitHub", 5), pair("Clavio", "Klaviyo", 3)])
        self.assertEqual([e["heard"] for e in bundle["entries"]], ["Clavio", "git hub"])
        self.assertEqual(bundle["about"], "x")
        self.assertIn("`Clavio` → `Klaviyo` (3 Macs)", report)

    def test_skips_rare_personal_foreign_common_and_growing(self):
        bundle, report = self.run_merge([
            pair("Clavio", "Klaviyo", 2),
            pair("noah at gmail", "noah@gmail.com", 9),
            pair("pin", "4321", 9),
            pair("ola", "olá", 9, languages="pt"),
            pair("their", "there", 9),
            pair("noah", "noah kagan", 9),
        ])
        self.assertEqual(bundle["entries"], [])
        for why in ["under 3 Macs", "fails the share scrub", "non-English", "common word", "second dictionary pass"]:
            self.assertIn(why, report)

    def test_conflicts_need_a_clear_winner(self):
        bundle, _ = self.run_merge([pair("clod", "Claude", 6), pair("clod", "Clawd", 3)])
        self.assertEqual([e["corrected"] for e in bundle["entries"]], ["Claude"])
        bundle, report = self.run_merge([pair("clod", "Claude", 4), pair("clod", "Clawd", 3)])
        self.assertEqual(bundle["entries"], [])
        self.assertIn("no clear winner", report)

    def test_never_changes_existing_entries(self):
        bundle, _ = self.run_merge([pair("Clavio", "Klavio", 9)], entries=[{"heard": "clavio", "corrected": "Klaviyo"}])
        self.assertEqual(bundle["entries"], [{"heard": "clavio", "corrected": "Klaviyo"}])

    def test_caps_additions_per_run(self):
        pairs = [pair(f"brand {chr(97 + i // 26)}{chr(97 + i % 26)}", f"Brand{chr(65 + i // 26)}{chr(97 + i % 26)}", 3) for i in range(80)]
        bundle, _ = self.run_merge(pairs)
        self.assertEqual(len(bundle["entries"]), m.MAX_NEW)

    def test_no_change_reports_false(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "s.json").write_text(json.dumps({"pairs": []}))
            original = json.dumps({"version": 1, "entries": []})
            (d / "b.json").write_text(original)
            m.main(["--summary", str(d / "s.json"), "--bundle", str(d / "b.json"), "--report", str(d / "r.md")])
            self.assertEqual((d / "b.json").read_text(), original, "untouched when nothing is added")

    def test_scrub_matches_the_website_and_app_patterns(self):
        """The three copies of the personal-data patterns must not drift apart."""
        swift = (REPO / "OpenSuperWhisper/Utils/CorrectionReporter.swift").read_text()
        ts = (REPO / "website/app/_lib/corrections.ts").read_text()
        for snippet in ["(sk|pk|rk|ghp|gho|xox[abp]|akia)", "{24,}", "{12,}", "(com|net|org|io|app|ai|co|dev|me|us|uk|de)"]:
            self.assertIn(snippet, swift)
            self.assertIn(snippet, ts)
        self.assertIn("MAX_WORDS = 5", ts)
        self.assertIn("maxWords = 5", swift)

    def test_bundled_file_is_valid(self):
        data = json.loads((REPO / "OpenSuperWhisper/CommonCorrections.json").read_text())
        self.assertEqual(data["version"], 1)
        for e in data["entries"]:
            self.assertTrue(m.shareable(e["heard"]) and m.shareable(e["corrected"]), e)


if __name__ == "__main__":
    unittest.main()
