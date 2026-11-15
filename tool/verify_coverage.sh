#!/usr/bin/env bash
# Native package-source line coverage, identical locally and in CI.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p coverage
# Prevent a failed test run from reusing stale coverage.
rm -f coverage/lcov.info
flutter test --coverage --reporter json | tee coverage/flutter-test.jsonl
python3 tool/coverage_report.py coverage/lcov.info \
  --minimum 80 \
  --required-sources tool/coverage_required_sources.txt \
  --json coverage/summary.json
