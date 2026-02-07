"""Data models for Flutter MCP server."""

from dataclasses import dataclass, field
from typing import List, Optional, Literal
from datetime import datetime


@dataclass
class TestFailure:
    """Represents a failed test."""
    test: str
    file: str
    line: Optional[int] = None
    error: str = ""
    stackTrace: Optional[List[str]] = None
    type: Literal["timeout", "assertion", "exception", "compilation"] = "assertion"


@dataclass
class SkippedTest:
    """Represents a skipped test."""
    test: str
    file: str
    reason: Optional[str] = None


@dataclass
class TestSummary:
    """Summary of test results."""
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    total: int = 0
    duration: float = 0.0


@dataclass
class TestResult:
    """Complete test run result."""
    success: bool
    summary: TestSummary
    failures: Optional[List[TestFailure]] = None
    skipped: Optional[List[SkippedTest]] = None
    warnings: Optional[List[str]] = None
    coveragePercent: Optional[float] = None
    runId: str = ""
    timestamp: datetime = field(default_factory=datetime.now)


@dataclass
class AnalyzeIssue:
    """Represents an analysis issue."""
    severity: Literal["error", "warning", "info", "hint"]
    type: str
    message: str
    file: str
    line: int
    column: int
    correction: Optional[str] = None


@dataclass
class AnalyzeSummary:
    """Summary of analysis results."""
    errors: int = 0
    warnings: int = 0
    infos: int = 0
    hints: int = 0


@dataclass
class AnalyzeResult:
    """Complete analyze run result."""
    success: bool
    summary: AnalyzeSummary
    issues: Optional[List[AnalyzeIssue]] = None
    runId: str = ""
    timestamp: datetime = field(default_factory=datetime.now)


@dataclass
class BuildError:
    """Represents a build error."""
    message: str
    file: Optional[str] = None
    line: Optional[int] = None


@dataclass
class BuildResult:
    """Complete build run result."""
    success: bool
    output: Optional[str] = None
    size: Optional[int] = None
    duration: float = 0.0
    errors: Optional[List[BuildError]] = None
    warnings: Optional[List[str]] = None
    runId: str = ""
    timestamp: datetime = field(default_factory=datetime.now)


@dataclass
class ValidationResult:
    """Result of running validation (analyze + test)."""
    success: bool
    analyze: AnalyzeResult
    test: Optional[TestResult] = None
    duration: float = 0.0
    runId: str = ""
    timestamp: datetime = field(default_factory=datetime.now)


@dataclass
class CoverageFile:
    """Coverage data for a single file."""
    path: str
    lines: int
    covered: int
    percent: float
    uncoveredLines: Optional[List[int]] = None


@dataclass
class CoverageSummary:
    """Overall coverage summary."""
    lines: int
    covered: int
    percent: float


@dataclass
class CoverageResult:
    """Complete coverage report."""
    overall: CoverageSummary
    files: Optional[List[CoverageFile]] = None
    lcov: Optional[str] = None
