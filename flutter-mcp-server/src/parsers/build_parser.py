"""Parser for Flutter build output."""

import re
from typing import List
from ..models import BuildResult, BuildError


class BuildParser:
    """Parse Flutter build output into structured data."""

    # Patterns for build output
    BUILD_COMPLETE_PATTERN = re.compile(r'Built\s+(.+)\s+\(([0-9.]+\s*[KMG]?B)\)')
    BUILD_ERROR_PATTERN = re.compile(r'FAILURE:|Error:|Exception:')
    GRADLE_ERROR_PATTERN = re.compile(r'^\* What went wrong:')
    FILE_LINE_PATTERN = re.compile(r'(.+\.dart):(\d+):(\d+):\s*error:\s*(.+)')

    def parse(self, output: str, success: bool) -> BuildResult:
        """Parse Flutter build output into BuildResult."""
        lines = output.split('\n')

        errors: List[BuildError] = []
        warnings: List[str] = []
        output_path = None
        size_bytes = None

        # Look for build completion info
        for line in lines:
            build_match = self.BUILD_COMPLETE_PATTERN.search(line)
            if build_match:
                output_path = build_match.group(1).strip()
                size_str = build_match.group(2).strip()
                size_bytes = self._parse_size(size_str)

        # Parse errors if build failed
        if not success:
            collecting_error = False
            current_error_lines: List[str] = []

            for line in lines:
                # Check for file:line errors (Dart compiler errors)
                file_line_match = self.FILE_LINE_PATTERN.match(line)
                if file_line_match:
                    file_path, line_num, col, error_msg = file_line_match.groups()
                    errors.append(BuildError(
                        message=error_msg.strip(),
                        file=file_path.strip(),
                        line=int(line_num)
                    ))
                    continue

                # Check for Gradle/build tool errors
                if self.GRADLE_ERROR_PATTERN.match(line):
                    collecting_error = True
                    current_error_lines = []
                    continue

                if collecting_error:
                    if line.strip().startswith('* Try:') or line.strip().startswith('* Get'):
                        # End of error block
                        if current_error_lines:
                            errors.append(BuildError(
                                message=' '.join(current_error_lines)
                            ))
                        collecting_error = False
                    elif line.strip():
                        current_error_lines.append(line.strip())

                # Generic error detection
                if self.BUILD_ERROR_PATTERN.search(line) and not file_line_match:
                    # Extract error message
                    error_text = line.strip()
                    if error_text and not any(e.message == error_text for e in errors):
                        errors.append(BuildError(message=error_text))

                # Look for warnings
                if 'warning:' in line.lower() and 'error' not in line.lower():
                    warnings.append(line.strip())

        return BuildResult(
            success=success,
            output=output_path,
            size=size_bytes,
            errors=errors if errors else None,
            warnings=warnings if warnings else None
        )

    def _parse_size(self, size_str: str) -> int:
        """Parse size string like '5.2MB' into bytes."""
        size_str = size_str.strip().upper()

        # Extract number and unit
        match = re.match(r'([0-9.]+)\s*([KMGT]?B)?', size_str)
        if not match:
            return 0

        number = float(match.group(1))
        unit = match.group(2) or 'B'

        multipliers = {
            'B': 1,
            'KB': 1024,
            'MB': 1024 ** 2,
            'GB': 1024 ** 3,
            'TB': 1024 ** 4
        }

        return int(number * multipliers.get(unit, 1))
