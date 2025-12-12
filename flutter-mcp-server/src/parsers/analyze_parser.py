"""Parser for Flutter analyze output."""

import re
from typing import List
from ..models import AnalyzeResult, AnalyzeSummary, AnalyzeIssue


class AnalyzeParser:
    """Parse Flutter analyze output into structured data."""

    # Pattern: severity • message • file:line:column • code
    # Example: error • Undefined name 'foo' • lib/main.dart:10:5 • undefined_identifier
    ISSUE_PATTERN = re.compile(
        r'^\s*(error|warning|info|hint)\s+[•·]\s+(.+?)\s+[•·]\s+(.+?):(\d+):(\d+)\s+[•·]\s+(\S+)'
    )

    # Summary pattern: "X issues found."
    SUMMARY_PATTERN = re.compile(r'(\d+)\s+issue[s]?\s+found')

    # No issues pattern
    NO_ISSUES_PATTERN = re.compile(r'No issues found!|Analyzing.*completed')

    def parse(self, output: str) -> AnalyzeResult:
        """Parse Flutter analyze output into AnalyzeResult."""
        lines = output.split('\n')

        issues: List[AnalyzeIssue] = []
        summary = AnalyzeSummary()

        for line in lines:
            # Check for "no issues" message
            if self.NO_ISSUES_PATTERN.search(line):
                continue

            # Parse issue line
            issue_match = self.ISSUE_PATTERN.match(line)
            if issue_match:
                severity, message, file_path, line_num, col, code = issue_match.groups()

                issue = AnalyzeIssue(
                    severity=severity,
                    type=code,
                    message=message.strip(),
                    file=file_path.strip(),
                    line=int(line_num),
                    column=int(col)
                )
                issues.append(issue)

                # Update summary counts
                if severity == 'error':
                    summary.errors += 1
                elif severity == 'warning':
                    summary.warnings += 1
                elif severity == 'info':
                    summary.infos += 1
                elif severity == 'hint':
                    summary.hints += 1

        # Parse summary if present
        for line in lines:
            summary_match = self.SUMMARY_PATTERN.search(line)
            if summary_match:
                total_issues = int(summary_match.group(1))
                # Verify our count matches
                counted = summary.errors + summary.warnings + summary.infos + summary.hints
                if counted == 0:
                    # If we didn't parse individual issues, distribute to errors
                    summary.errors = total_issues

        # Determine success (no errors)
        success = summary.errors == 0

        return AnalyzeResult(
            success=success,
            summary=summary,
            issues=issues if issues else None
        )

    def parse_machine_format(self, output: str) -> AnalyzeResult:
        """Parse machine-readable format (if Flutter provides it)."""
        # Flutter analyze can output JSON with --machine flag
        # This is a placeholder for future enhancement
        return self.parse(output)
