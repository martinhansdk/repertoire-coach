#!/usr/bin/env python3
"""Test script to verify the cache corruption fix."""

import asyncio
import sys
from pathlib import Path

# Add parent directory to path to import as package
sys.path.insert(0, str(Path(__file__).parent))

from src.cache import ResultCache
from src.models import TestResult, TestSummary, TestFailure, AnalyzeResult, AnalyzeSummary, AnalyzeIssue
from src.server import FlutterMCPServer


async def test_get_test_results_does_not_corrupt_cache():
    """Verify that get_test_results doesn't modify the cached object."""
    print("Testing get_test_results cache corruption fix...")

    # Create server with cache
    server = FlutterMCPServer()

    # Create a test result with 3 failures
    failures = [
        TestFailure(test="test1", file="file1.dart", error="error in file1"),
        TestFailure(test="test2", file="file2.dart", error="error in file2"),
        TestFailure(test="test3", file="file1.dart", error="another error in file1"),
    ]

    result = TestResult(
        success=False,
        summary=TestSummary(passed=0, failed=3, total=3),
        failures=failures
    )

    # Store in cache
    run_id = server.cache.store_test_result(result, {})
    print(f"  Stored test result with {len(failures)} failures, run_id: {run_id}")

    # First call: filter by file1.dart (should return 2 failures)
    args1 = {"runId": run_id, "file": "file1.dart", "maxFailures": 0}
    result1 = await server._get_test_results(args1)
    print(f"  First call (filter file1.dart): returned {len(result1['failures'])} failures")
    assert len(result1['failures']) == 2, f"Expected 2 failures, got {len(result1['failures'])}"

    # Second call: no filter (should return all 3 failures)
    args2 = {"runId": run_id, "maxFailures": 0}
    result2 = await server._get_test_results(args2)
    print(f"  Second call (no filter): returned {len(result2['failures'])} failures")
    assert len(result2['failures']) == 3, f"Expected 3 failures, got {len(result2['failures'])} - CACHE WAS CORRUPTED!"

    # Third call: different filter by file2.dart (should return 1 failure)
    args3 = {"runId": run_id, "file": "file2.dart", "maxFailures": 0}
    result3 = await server._get_test_results(args3)
    print(f"  Third call (filter file2.dart): returned {len(result3['failures'])} failures")
    assert len(result3['failures']) == 1, f"Expected 1 failure, got {len(result3['failures'])}"

    print("✓ get_test_results test PASSED - cache is not corrupted\n")


async def test_get_analyze_results_does_not_corrupt_cache():
    """Verify that get_analyze_results doesn't modify the cached object."""
    print("Testing get_analyze_results cache corruption fix...")

    # Create server with cache
    server = FlutterMCPServer()

    # Create an analyze result with 4 issues
    issues = [
        AnalyzeIssue(severity="error", type="type_error", message="error in file1",
                     file="file1.dart", line=10, column=5),
        AnalyzeIssue(severity="warning", type="warning_type", message="warning in file2",
                     file="file2.dart", line=20, column=10),
        AnalyzeIssue(severity="info", type="info_type", message="info in file1",
                     file="file1.dart", line=30, column=15),
        AnalyzeIssue(severity="error", type="type_error", message="another error in file1",
                     file="file1.dart", line=40, column=20),
    ]

    result = AnalyzeResult(
        success=False,
        summary=AnalyzeSummary(errors=2, warnings=1, infos=1),
        issues=issues
    )

    # Store in cache
    run_id = server.cache.store_analyze_result(result, {})
    print(f"  Stored analyze result with {len(issues)} issues, run_id: {run_id}")

    # First call: filter by severity=error (should return 2 issues)
    args1 = {"runId": run_id, "severity": "error", "maxIssues": 0}
    result1 = await server._get_analyze_results(args1)
    print(f"  First call (filter severity=error): returned {len(result1['issues'])} issues")
    assert len(result1['issues']) == 2, f"Expected 2 issues, got {len(result1['issues'])}"

    # Second call: no filter (should return all 4 issues)
    args2 = {"runId": run_id, "maxIssues": 0}
    result2 = await server._get_analyze_results(args2)
    print(f"  Second call (no filter): returned {len(result2['issues'])} issues")
    assert len(result2['issues']) == 4, f"Expected 4 issues, got {len(result2['issues'])} - CACHE WAS CORRUPTED!"

    # Third call: filter by file (should return 3 issues)
    args3 = {"runId": run_id, "file": "file1.dart", "maxIssues": 0}
    result3 = await server._get_analyze_results(args3)
    print(f"  Third call (filter file1.dart): returned {len(result3['issues'])} issues")
    assert len(result3['issues']) == 3, f"Expected 3 issues, got {len(result3['issues'])}"

    # Fourth call: unique types (should return 3 unique type issues from all 4)
    args4 = {"runId": run_id, "uniqueTypes": True, "maxIssues": 0}
    result4 = await server._get_analyze_results(args4)
    print(f"  Fourth call (unique types): returned {len(result4['issues'])} issues")
    assert len(result4['issues']) == 3, f"Expected 3 issues, got {len(result4['issues'])}"

    print("✓ get_analyze_results test PASSED - cache is not corrupted\n")


async def main():
    """Run all tests."""
    print("=" * 60)
    print("Testing MCP server cache corruption fix")
    print("=" * 60 + "\n")

    try:
        await test_get_test_results_does_not_corrupt_cache()
        await test_get_analyze_results_does_not_corrupt_cache()

        print("=" * 60)
        print("✓ ALL TESTS PASSED")
        print("=" * 60)
        return 0
    except AssertionError as e:
        print(f"\n✗ TEST FAILED: {e}")
        return 1
    except Exception as e:
        print(f"\n✗ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
