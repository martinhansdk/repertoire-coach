"""Parser for Flutter test output."""

import re
from typing import List, Optional
from ..models import TestResult, TestSummary, TestFailure, SkippedTest


class TestParser:
    """Parse Flutter test output into structured data."""

    # Patterns for parsing test output
    TEST_LINE_PATTERN = re.compile(
        r'^\s*(\d{2}:\d{2})\s+([+\-~])(\d+)(?:\s+[+\-~]\d+)*:\s+(.+)$'
    )
    SUMMARY_PATTERN = re.compile(
        r'^\s*(\d+)\s+tests?\s+passed,\s+(\d+)\s+failed,\s+(\d+)\s+skipped'
    )
    FAILURE_HEADER_PATTERN = re.compile(
        r'^\s*(\d{2}:\d{2})\s+\+\d+\s+-(\d+)(?:\s+~\d+)?:\s+(.+)\s+\[E\]'
    )
    FILE_LINE_PATTERN = re.compile(r'^\s*(.+\.dart):(\d+):(\d+)\s*$')
    COMPILATION_ERROR_PATTERN = re.compile(
        r'Error: (.+\.dart):(\d+):(\d+):\s+(.+)'
    )
    TIMEOUT_PATTERN = re.compile(r'Test timed out after \d+')

    def __init__(self):
        self.current_failure: Optional[TestFailure] = None
        self.in_stack_trace = False

    def parse(self, output: str) -> TestResult:
        """Parse Flutter test output into TestResult."""
        lines = output.split('\n')

        summary = TestSummary()
        failures: List[TestFailure] = []
        skipped: List[SkippedTest] = []
        warnings: List[str] = []

        # Track current test being processed
        current_test_name = ""
        current_test_file = ""
        error_message_lines: List[str] = []
        stack_trace_lines: List[str] = []
        collecting_error = False

        for i, line in enumerate(lines):
            # Parse test progress line (e.g., "00:05 +42 -1 ~3: test_file.dart: Test Name")
            test_match = self.TEST_LINE_PATTERN.match(line)
            if test_match:
                time, status, count, description = test_match.groups()

                # Extract ALL status+count pairs from the line (compact reporter includes all)
                # Find all patterns like "+42", "-1", "~3" in the line
                all_counts = re.findall(r'([+\-~])(\d+)', line)
                for stat, cnt in all_counts:
                    if stat == '+':
                        summary.passed = int(cnt)
                    elif stat == '-':
                        summary.failed = int(cnt)
                        collecting_error = True
                        error_message_lines = []
                        stack_trace_lines = []
                    elif stat == '~':
                        summary.skipped = int(cnt)

                # Extract file and test name from description
                parts = description.split(': ')
                if len(parts) >= 2:
                    current_test_file = parts[0].strip()
                    current_test_name = ': '.join(parts[1:]).strip()
                else:
                    current_test_name = description.strip()

                continue

            # Parse compilation errors
            comp_error_match = self.COMPILATION_ERROR_PATTERN.match(line)
            if comp_error_match:
                file_path, line_num, col, error_msg = comp_error_match.groups()
                failures.append(TestFailure(
                    test="Compilation Error",
                    file=file_path,
                    line=int(line_num),
                    error=error_msg.strip(),
                    type="compilation"
                ))
                summary.failed += 1
                continue

            # Check for timeout
            if self.TIMEOUT_PATTERN.search(line):
                if current_test_name:
                    failures.append(TestFailure(
                        test=current_test_name,
                        file=current_test_file,
                        error="Test timed out",
                        type="timeout"
                    ))
                continue

            # Collect error messages and stack traces
            if collecting_error:
                stripped = line.strip()

                # Check if this line starts a new test (ends error block)
                if self.TEST_LINE_PATTERN.match(line):
                    # Save current error before processing new test
                    if current_test_name and error_message_lines:
                        error_text = ' '.join(error_message_lines)
                        error_type = "assertion"
                        if "Exception" in error_text or "Error" in error_text:
                            error_type = "exception"
                        failures.append(TestFailure(
                            test=current_test_name,
                            file=current_test_file,
                            error=error_text,
                            stackTrace=stack_trace_lines if stack_trace_lines else None,
                            type=error_type
                        ))
                    collecting_error = False
                    error_message_lines = []
                    stack_trace_lines = []
                    # Don't continue - let the test line be processed normally
                # Look for stack trace lines (contain package: or file:line:col pattern)
                elif 'package:' in line or (stripped and '.dart:' in stripped and ':' in stripped.split('.dart:')[-1]):
                    stack_trace_lines.append(stripped)
                # Capture error message lines (Expected:, Actual:, Which:, or other indented content)
                elif stripped.startswith(('Expected:', 'Actual:', 'Which:')):
                    error_message_lines.append(stripped)
                # Empty line after collecting content - save the error
                elif not stripped and error_message_lines:
                    # Save collected error
                    if current_test_name:
                        error_text = ' '.join(error_message_lines)
                        error_type = "assertion"
                        if "Exception" in error_text or "Error" in error_text:
                            error_type = "exception"
                        failures.append(TestFailure(
                            test=current_test_name,
                            file=current_test_file,
                            error=error_text,
                            stackTrace=stack_trace_lines if stack_trace_lines else None,
                            type=error_type
                        ))
                    collecting_error = False
                    error_message_lines = []
                    stack_trace_lines = []
                # Other non-empty indented lines are part of error message
                elif stripped and line.startswith(' '):
                    error_message_lines.append(stripped)

            # Parse summary line
            summary_match = self.SUMMARY_PATTERN.search(line)
            if summary_match:
                passed, failed, skip = summary_match.groups()
                summary.passed = int(passed)
                summary.failed = int(failed)
                summary.skipped = int(skip)

            # Look for warnings
            if 'Warning:' in line:
                warnings.append(line.strip())

        # Save any remaining error that was being collected when output ended
        if collecting_error and current_test_name and error_message_lines:
            error_text = ' '.join(error_message_lines)
            error_type = "assertion"
            if "Exception" in error_text or "Error" in error_text:
                error_type = "exception"
            failures.append(TestFailure(
                test=current_test_name,
                file=current_test_file,
                error=error_text,
                stackTrace=stack_trace_lines if stack_trace_lines else None,
                type=error_type
            ))

        # If we didn't find a summary line, extract final counts from the last progress line
        # This handles the compact reporter format which doesn't have a summary line
        if summary.total == 0 and summary.passed == 0:
            # Find the last line with test progress (e.g., "00:53 +586 ~52:")
            for line in reversed(lines):
                test_match = self.TEST_LINE_PATTERN.match(line)
                if test_match:
                    # Found the last progress line, use these as final counts
                    break

        # Calculate total
        summary.total = summary.passed + summary.failed + summary.skipped

        # Determine success
        success = summary.failed == 0 and summary.total > 0

        return TestResult(
            success=success,
            summary=summary,
            failures=failures if failures else None,
            skipped=skipped if skipped else None,
            warnings=warnings if warnings else None
        )

    def parse_compact_output(self, output: str) -> TestResult:
        """Parse compact test output format."""
        lines = output.split('\n')

        passed = 0
        failed = 0
        skipped = 0

        for line in lines:
            if '+' in line and 'passed' in line.lower():
                # Extract numbers
                match = re.search(r'\+(\d+)', line)
                if match:
                    passed = int(match.group(1))

            if failed == 0 and '-' in line:
                match = re.search(r'-(\d+)', line)
                if match:
                    failed = int(match.group(1))

            if '~' in line:
                match = re.search(r'~(\d+)', line)
                if match:
                    skipped = int(match.group(1))

        total = passed + failed + skipped
        success = failed == 0 and total > 0

        return TestResult(
            success=success,
            summary=TestSummary(
                passed=passed,
                failed=failed,
                skipped=skipped,
                total=total
            )
        )
