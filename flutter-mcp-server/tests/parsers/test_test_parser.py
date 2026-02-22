"""Unit tests for the Flutter test output parser.

The compact test reporter uses \\r (carriage return) to overwrite progress
lines in the terminal. When captured via subprocess.PIPE these \\r characters
are preserved in the raw output, creating long lines where many progress
updates are \\r-separated within a single \\n-terminated chunk.

These tests verify that the parser handles this format correctly.
"""

import re
from pathlib import Path

import pytest

from src.parsers.test_parser import TestParser as FlutterTestParser

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _fixture(name: str) -> str:
    return (FIXTURES_DIR / name).read_text()


def _make_cr_log(passed: int, skipped: int = 0) -> str:
    """Build a minimal compact-reporter log with \\r-separated progress lines."""
    # Each second the reporter rewrites the progress line with \\r.
    # We simulate several rewrites on one \\n-terminated chunk.
    progress = "".join(
        f"\r00:{i:02d} +{i} ~{skipped}: /app/test/foo_test.dart: test_{i}   "
        for i in range(1, passed + 1)
    )
    return progress + f"\r00:{passed:02d} +{passed} ~{skipped}: All tests passed!   \n"


# ---------------------------------------------------------------------------
# Basic parsing
# ---------------------------------------------------------------------------

class TestBasicParsing:
    def test_all_passing_returns_success(self):
        log = _make_cr_log(passed=5)
        result = FlutterTestParser().parse(log)
        assert result.success is True
        assert result.summary.passed == 5
        assert result.summary.failed == 0
        assert result.summary.skipped == 0

    def test_skips_not_counted_as_failures(self):
        log = _make_cr_log(passed=3, skipped=2)
        result = FlutterTestParser().parse(log)
        assert result.success is True
        assert result.summary.passed == 3
        assert result.summary.skipped == 2
        assert result.summary.failed == 0


# ---------------------------------------------------------------------------
# Carriage-return handling (the core regression)
# ---------------------------------------------------------------------------

class TestCarriageReturnHandling:
    """The compact reporter emits \\r to overwrite terminal lines.
    Many progress updates appear within a single \\n-terminated chunk.
    The parser must not miscount +/- symbols across \\r boundaries.
    """

    def test_cr_separated_progress_does_not_inflate_failure_count(self):
        # Simulate a single \\n-terminated "line" that actually contains
        # 200 \\r-separated progress updates (as produced by a 200-second run).
        chunks = "".join(
            f"\r{i:02d}:{i:02d} +{i} ~0: /app/test/foo_test.dart: test_{i}   "
            for i in range(1, 201)
        )
        log = chunks + "\r03:21 +200 ~0: All tests passed!   \n"
        result = FlutterTestParser().parse(log)
        assert result.summary.failed == 0
        assert result.summary.passed == 200
        assert result.success is True

    def test_cr_and_newline_mixed(self):
        """Skip messages appear as \\n-terminated lines between \\r-progress chunks."""
        log = (
            "\r00:00 +0: loading /app/test/bar_test.dart   "
            "\r00:01 +0: /app/test/bar_test.dart: skipped test   "
            "\r00:01 +0: /app/test/bar_test.dart: skipped test   "
            "\n  Skip: Requires path_provider platform implementation\n"
            "\r00:01 +0 ~1: /app/test/bar_test.dart: skipped test   "
            "\r00:01 +1 ~1: /app/test/bar_test.dart: passing test   "
            "\r00:01 +1 ~1: All tests passed!   \n"
        )
        result = FlutterTestParser().parse(log)
        assert result.summary.failed == 0
        assert result.summary.passed == 1
        assert result.summary.skipped == 1
        assert result.success is True

    def test_drift_warnings_in_output_do_not_cause_failures(self):
        """Drift emits multi-line warnings with stack traces; they must be ignored."""
        log = (
            "\r00:01 +1: /app/test/foo_test.dart: test A   \n"
            "WARNING (drift): It looks like you've created the database class "
            "AppDatabase multiple times. When these two databases use the same "
            "QueryExecutor, race conditions will occur.\n"
            "Try to follow the advice at https://drift.simonbinder.eu/faq/\n"
            "#0      GeneratedDatabase._handleInstantiated "
            "(package:drift/src/runtime/api/db_base.dart:96:30)\n"
            "#1      main.<anonymous closure> "
            "(file:///app/test/presentation/screens/foo_test.dart:39:33)\n"
            "This warning will only appear on debug builds.\n"
            "\r00:02 +2 ~0: /app/test/foo_test.dart: test B   "
            "\r00:02 +2 ~0: All tests passed!   \n"
        )
        result = FlutterTestParser().parse(log)
        assert result.summary.failed == 0
        assert result.summary.passed == 2
        assert result.success is True


# ---------------------------------------------------------------------------
# Failure detection
# ---------------------------------------------------------------------------

class TestFailureDetection:
    def test_single_failure_detected(self):
        log = (
            "\r00:01 +0: /app/test/foo_test.dart: passing test   "
            "\r00:01 +1: /app/test/foo_test.dart: passing test   "
            "\r00:01 +1 -1: /app/test/foo_test.dart: failing test [E]   \n"
            "Expected: <42>\n"
            "  Actual: <0>\n"
            "\r00:02 +1 -1: Some tests failed.   \n"
        )
        result = FlutterTestParser().parse(log)
        assert result.summary.failed == 1
        assert result.summary.passed == 1
        assert result.success is False

    def test_failure_count_accumulates(self):
        log = (
            "\r00:01 +0 -1: /app/test/a_test.dart: first fail [E]   \n"
            "Expected: true\n"
            "  Actual: false\n"
            "\r00:02 +0 -2: /app/test/b_test.dart: second fail [E]   \n"
            "Expected: 'hello'\n"
            "  Actual: 'world'\n"
            "\r00:03 +0 -2: Some tests failed.   \n"
        )
        result = FlutterTestParser().parse(log)
        assert result.summary.failed == 2
        assert result.success is False


# ---------------------------------------------------------------------------
# Fixture-based regression tests
# ---------------------------------------------------------------------------

class TestFixtures:
    def test_all_passing_fixture_reports_success(self):
        """The captured log from an all-green test run must parse as success."""
        log = _fixture("test_output_all_passing.txt")
        result = FlutterTestParser().parse(log)
        # The fixture ends with '+852 ~54: All tests passed!'
        assert result.summary.failed == 0, (
            f"Expected 0 failures but got {result.summary.failed}. "
            f"Failures: {result.failures}"
        )
        assert result.summary.passed > 0
        assert result.success is True

    def test_all_passing_fixture_skip_count(self):
        log = _fixture("test_output_all_passing.txt")
        result = FlutterTestParser().parse(log)
        # 54 tests are marked skip: true in the fixture run
        assert result.summary.skipped == 54

    def test_failure_fixture_detects_failure(self):
        log = _fixture("test_output_with_failure.txt")
        result = FlutterTestParser().parse(log)
        assert result.summary.failed >= 1
        assert result.success is False
