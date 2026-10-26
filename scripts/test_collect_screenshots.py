import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import collect_screenshots as subject  # noqa: E402


class CollectScreenshotsTests(unittest.TestCase):
    def test_uses_manifest_names_without_xcode_suffix(self):
        with tempfile.TemporaryDirectory() as raw, tempfile.TemporaryDirectory() as out:
            Path(raw, 'A1.png').write_bytes(b'png')
            manifest = [{'testIdentifier': 'T/test()', 'attachments': [{
                'exportedFileName': 'A1.png',
                'suggestedHumanReadableName': 'frost-Today-default_0_8F1C2E7A-1B2C-4D5E-8F90-123456789ABC.png'}]}]
            Path(raw, 'manifest.json').write_text(json.dumps(manifest))
            self.assertEqual(subject.collect(Path(raw), Path(out)), ['frost-Today-default.png'])

    def test_keeps_unnamed_images_and_avoids_collisions(self):
        with tempfile.TemporaryDirectory() as raw, tempfile.TemporaryDirectory() as out:
            Path(raw, 'one.png').write_bytes(b'1')
            Path(raw, 'two.png').write_bytes(b'2')
            Path(raw, 'notes.txt').write_text('skip')
            Path(raw, 'manifest.json').write_text(json.dumps([
                {'exportedFileName': 'one.png', 'suggestedHumanReadableName': 'Screen'},
                {'exportedFileName': 'two.png', 'suggestedHumanReadableName': 'Screen'}]))
            self.assertEqual(subject.collect(Path(raw), Path(out)), ['Screen.png', 'Screen-2.png'])

    def test_works_without_manifest(self):
        with tempfile.TemporaryDirectory() as raw, tempfile.TemporaryDirectory() as out:
            Path(raw, 'X.jpg').write_bytes(b'j')
            self.assertEqual(subject.collect(Path(raw), Path(out)), ['X.jpg'])


if __name__ == '__main__':
    unittest.main()
