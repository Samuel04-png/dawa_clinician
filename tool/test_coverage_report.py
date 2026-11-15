import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from coverage_report import parse_lcov, summarize


class CoverageReportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / 'lib').mkdir()
        (self.root / 'lib/app.dart').write_text('first\nsecond\n')
        self.raw = 'SF:lib/app.dart\nDA:1,1\nDA:2,0\nLF:2\nLH:1\nend_of_record\n'

    def tearDown(self):
        self.temporary.cleanup()

    def test_actual_counts(self):
        result = summarize(parse_lcov(self.raw, self.root))
        self.assertEqual((result['covered'], result['total'], result['percent']), (1, 2, 50))
        self.assertEqual(result['files']['lib/app.dart']['uncovered_lines'], [2])

    def test_rejects_missing_empty_and_truncated_records(self):
        for raw in ['', 'end_of_record', 'SF:lib/app.dart\nend_of_record', self.raw.replace('end_of_record', '')]:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                parse_lcov(raw, self.root)

    def test_rejects_altered_totals_invalid_counts_and_duplicate_records(self):
        for raw in [self.raw.replace('LH:1', 'LH:2'), self.raw.replace('LF:2', 'LF:1'),
                    self.raw.replace('DA:1,1', 'DA:1,-1'), self.raw + self.raw,
                    self.raw.replace('DA:2,0', 'DA:1,0'), self.raw.replace('DA:2,0', 'DA:3,0')]:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                parse_lcov(raw, self.root)

    def test_cli_enforces_actual_threshold_and_rejects_missing_input(self):
        lcov = self.root / 'lcov.info'
        lcov.write_text(self.raw)
        command = [sys.executable, str(Path(__file__).with_name('coverage_report.py')), str(lcov), '--root', str(self.root)]
        accepted = subprocess.run(command + ['--minimum', '50'], capture_output=True, text=True)
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        rejected = subprocess.run(command + ['--minimum', '80'], capture_output=True, text=True)
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn('below 80%', rejected.stderr)
        lcov.unlink()
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

    def test_cli_rejects_previously_instrumented_source_disappearing(self):
        lcov = self.root / 'lcov.info'
        lcov.write_text(self.raw)
        required = self.root / 'required.txt'
        required.write_text('lib/app.dart\nlib/clinical.dart\n')
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('coverage_report.py')), str(lcov), '--root', str(self.root), '--required-sources', str(required)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Previously instrumented sources missing: lib/clinical.dart', result.stderr)

    def test_rejects_missing_or_nonproduction_sources(self):
        for name in ['test/app_test.dart', 'lib/../test.dart', 'lib/missing.dart']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                parse_lcov(self.raw.replace('lib/app.dart', name), self.root)


if __name__ == '__main__':
    unittest.main()
