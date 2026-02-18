"""Flutter MCP Server - Structured access to Flutter test/analyze/build operations."""

import json
import asyncio
import time
import os
import subprocess
from pathlib import Path
from typing import Any, Dict, Optional
from dataclasses import asdict

from mcp.server import Server
from mcp.types import Tool, TextContent, Resource, ResourceTemplate
import mcp.server.stdio

from .flutter_runner import FlutterRunner
from .cache import ResultCache
from .parsers import TestParser, AnalyzeParser, BuildParser
from .models import (
    TestResult, AnalyzeResult, BuildResult, ValidationResult,
    TestSummary, AnalyzeSummary, AnalyzeIssue, BuildError,
    TestFailure, SkippedTest
)
from datetime import datetime


class FlutterMCPServer:
    """MCP Server for Flutter operations."""

    def __init__(self, project_root: Optional[str] = None):
        self.server = Server("flutter-mcp-server")
        self.project_root = Path(project_root) if project_root else Path.cwd()
        self.running_procs: Dict[str, Any] = {}
        self.cancelled_runs: set[str] = set()

        # Initialize components
        # Use cirruslabs Flutter image - runs as root for consistent file permissions
        self.runner = FlutterRunner(
            docker_image="ghcr.io/cirruslabs/flutter:stable",
            project_root=str(self.project_root)
        )
        self.cache = ResultCache()
        self.test_parser = TestParser()
        self.analyze_parser = AnalyzeParser()
        self.build_parser = BuildParser()

        # Register handlers
        self._register_handlers()

    def _register_handlers(self):
        """Register all MCP handlers."""

        @self.server.list_tools()
        async def list_tools() -> list[Tool]:
            """List available tools."""
            return [
                Tool(
                    name="flutter_test",
                    description="Run Flutter tests with structured output",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "path": {"type": "string", "description": "Specific test file or directory"},
                            "name": {"type": "string", "description": "Filter by test name pattern"},
                            "failFast": {"type": "boolean", "description": "Stop on first failure"},
                            "coverage": {"type": "boolean", "description": "Generate coverage report"},
                            "verbose": {"type": "boolean", "description": "Include full output in cache"},
                            "dockerImage": {"type": "string", "description": "Docker image to use"},
                            "timeout": {"type": "number", "description": "Timeout in seconds"},
                            "async": {"type": "boolean", "description": "Run asynchronously (default: true)"}
                        }
                    }
                ),
                Tool(
                    name="flutter_analyze",
                    description="Run Flutter analysis with structured errors",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "path": {"type": "string", "description": "Specific file/directory"},
                            "severity": {"type": "string", "enum": ["info", "warning", "error"], "description": "Minimum severity"},
                            "maxIssues": {"type": "number", "description": "Max issues to return (default: 50, 0 for all)"},
                            "dockerImage": {"type": "string", "description": "Docker image to use"},
                            "timeout": {"type": "number", "description": "Timeout in seconds"},
                            "async": {"type": "boolean", "description": "Run asynchronously (default: true)"}
                        }
                    }
                ),
                Tool(
                    name="flutter_build",
                    description="Run Flutter build with structured output",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "target": {"type": "string", "enum": ["android", "ios", "web", "apk", "appbundle"], "description": "Build target"},
                            "mode": {"type": "string", "enum": ["debug", "profile", "release"], "description": "Build mode"},
                            "flavor": {"type": "string", "description": "Build flavor"},
                            "buildNumber": {"type": "string", "description": "Build number"},
                            "buildName": {"type": "string", "description": "Build name"},
                            "dartDefines": {"type": "object", "description": "Key-value pairs for --dart-define flags (e.g., {\"SUPABASE_URL\": \"...\", \"SUPABASE_ANON_KEY\": \"...\"})"},
                            "dockerImage": {"type": "string", "description": "Docker image to use"},
                            "timeout": {"type": "number", "description": "Timeout in seconds"},
                            "async": {"type": "boolean", "description": "Run asynchronously (default: true)"}
                        },
                        "required": ["target"]
                    }
                ),
                Tool(
                    name="get_test_results",
                    description="Query cached test results",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "runId": {"type": "string", "description": "Specific run ID"},
                            "failedOnly": {"type": "boolean", "description": "Only return failed tests"},
                            "file": {"type": "string", "description": "Filter by file path (substring match)"},
                            "searchMessage": {"type": "string", "description": "Search in test error messages (substring match)"},
                            "excludePattern": {"type": "string", "description": "Regex pattern to exclude from messages"},
                            "maxFailures": {"type": "number", "description": "Max failures to return (default: 50, 0 for all)"}
                        }
                    }
                ),
                Tool(
                    name="get_build_results",
                    description="Query cached build results",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "runId": {"type": "string", "description": "Specific run ID"}
                        }
                    }
                ),
                Tool(
                    name="get_validation_results",
                    description="Query cached validation results",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "runId": {"type": "string", "description": "Specific run ID"}
                        }
                    }
                ),
                Tool(
                    name="get_run_status",
                    description="Get status for an async run",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "runId": {"type": "string", "description": "Run ID"}
                        },
                        "required": ["runId"]
                    }
                ),
                Tool(
                    name="list_running",
                    description="List currently running async operations",
                    inputSchema={"type": "object", "properties": {}}
                ),
                Tool(
                    name="cancel_run",
                    description="Cancel a running async operation",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "runId": {"type": "string", "description": "Run ID"}
                        },
                        "required": ["runId"]
                    }
                ),
                Tool(
                    name="get_analyze_results",
                    description="Query cached analysis results",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "runId": {"type": "string", "description": "Specific run ID"},
                            "severity": {"type": "string", "enum": ["info", "warning", "error"], "description": "Filter by severity"},
                            "file": {"type": "string", "description": "Filter by file path (substring match)"},
                            "searchMessage": {"type": "string", "description": "Search in error messages (substring match)"},
                            "excludePattern": {"type": "string", "description": "Regex pattern to exclude from messages"},
                            "uniqueTypes": {"type": "boolean", "description": "Return only one issue per error type (deduplication)"},
                            "maxIssues": {"type": "number", "description": "Max issues to return (default: 50, 0 for all)"}
                        }
                    }
                ),
                Tool(
                    name="run_validation",
                    description="Run both analyze and test (like scripts/validate.sh)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "stopOnAnalyzeFailure": {"type": "boolean", "description": "Don't run tests if analyze fails"},
                            "testOptions": {
                                "type": "object",
                                "properties": {
                                    "path": {"type": "string"},
                                    "failFast": {"type": "boolean"},
                                    "coverage": {"type": "boolean"}
                                }
                            },
                            "dockerImage": {"type": "string", "description": "Docker image to use"},
                            "async": {"type": "boolean", "description": "Run asynchronously (default: true)"}
                        }
                    }
                ),
                Tool(
                    name="list_test_runs",
                    description="List recent test runs with summaries",
                    inputSchema={"type": "object", "properties": {}}
                ),
                Tool(
                    name="flutter_pub",
                    description="Run Flutter pub commands (get, upgrade, outdated)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "command": {"type": "string", "enum": ["get", "upgrade", "outdated"], "description": "Pub command to run"},
                            "dockerImage": {"type": "string", "description": "Docker image to use"},
                            "timeout": {"type": "number", "description": "Timeout in seconds"}
                        },
                        "required": ["command"]
                    }
                ),
                Tool(
                    name="get_raw_log",
                    description="Get the raw output log for a test/analyze/build run (for debugging parser issues)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "runId": {"type": "string", "description": "Run ID (e.g., test:20260115081506:44136fa3). If not specified, returns latest test run log."},
                            "tail": {"type": "number", "description": "Only return last N lines (default: all)"},
                            "head": {"type": "number", "description": "Only return first N lines (default: all)"}
                        }
                    }
                )
            ]

        @self.server.call_tool()
        async def call_tool(name: str, arguments: Any) -> list[TextContent]:
            """Handle tool calls."""
            args = arguments if isinstance(arguments, dict) else {}

            if name == "flutter_test":
                result = await self._flutter_test(args)
            elif name == "flutter_analyze":
                result = await self._flutter_analyze(args)
            elif name == "flutter_build":
                result = await self._flutter_build(args)
            elif name == "get_test_results":
                result = await self._get_test_results(args)
            elif name == "get_build_results":
                result = await self._get_build_results(args)
            elif name == "get_validation_results":
                result = await self._get_validation_results(args)
            elif name == "get_analyze_results":
                result = await self._get_analyze_results(args)
            elif name == "get_run_status":
                result = self.cache.get_status(args.get("runId", ""))
            elif name == "list_running":
                result = self.cache.list_running()
            elif name == "cancel_run":
                result = await self._cancel_run(args)
            elif name == "run_validation":
                result = await self._run_validation(args)
            elif name == "list_test_runs":
                result = self.cache.list_test_runs()
            elif name == "flutter_pub":
                result = await self._flutter_pub(args)
            elif name == "get_raw_log":
                result = await self._get_raw_log(args)
            else:
                raise ValueError(f"Unknown tool: {name}")

            return [TextContent(
                type="text",
                text=json.dumps(result, indent=2, default=str)
            )]

        @self.server.list_resources()
        async def list_resources() -> list[Resource]:
            """List available resources."""
            resources = []

            # Latest test result
            latest_test = self.cache.get_test_result()
            if latest_test:
                resources.append(Resource(
                    uri="test://latest",
                    name="Latest Test Results",
                    mimeType="application/json",
                    description="Most recent test run results"
                ))

            # Latest analyze result
            latest_analyze = self.cache.get_analyze_result()
            if latest_analyze:
                resources.append(Resource(
                    uri="analyze://latest",
                    name="Latest Analyze Results",
                    mimeType="application/json",
                    description="Most recent analyze run results"
                ))

            # Latest build result
            latest_build = self.cache.get_build_result()
            if latest_build:
                resources.append(Resource(
                    uri="build://latest",
                    name="Latest Build Results",
                    mimeType="application/json",
                    description="Most recent build run results"
                ))

            # Test runs list
            resources.append(Resource(
                uri="test://runs",
                name="Test Runs List",
                mimeType="application/json",
                description="List of recent test runs"
            ))

            return resources

        @self.server.read_resource()
        async def read_resource(uri: str) -> str:
            """Read a resource."""
            if uri == "test://latest":
                result = self.cache.get_test_result()
                if result:
                    return json.dumps(asdict(result), indent=2, default=str)
                return json.dumps({"error": "No test results available"})

            elif uri == "analyze://latest":
                result = self.cache.get_analyze_result()
                if result:
                    return json.dumps(asdict(result), indent=2, default=str)
                return json.dumps({"error": "No analyze results available"})

            elif uri == "build://latest":
                result = self.cache.get_build_result()
                if result:
                    return json.dumps(asdict(result), indent=2, default=str)
                return json.dumps({"error": "No build results available"})

            elif uri == "test://runs":
                runs = self.cache.list_test_runs()
                return json.dumps(runs, indent=2, default=str)

            elif uri.startswith("logs://test/"):
                run_id = uri.replace("logs://test/", "")
                log = self.cache.get_log(run_id)
                if log:
                    return log
                return "Log not found"

            elif uri.startswith("logs://analyze/"):
                run_id = uri.replace("logs://analyze/", "")
                log = self.cache.get_log(run_id)
                if log:
                    return log
                return "Log not found"

            raise ValueError(f"Unknown resource: {uri}")

    async def _flutter_test(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute flutter test command."""
        start_time = time.time()

        # Extract parameters
        path = args.get("path")
        name = args.get("name")
        fail_fast = args.get("failFast", False)
        coverage = args.get("coverage", False)
        verbose = args.get("verbose", False)
        timeout = args.get("timeout", 300)
        async_mode = args.get("async", True)

        # Update Docker image if specified
        if args.get("dockerImage"):
            self.runner.docker_image = args["dockerImage"]

        # Run test (pub get is automatically run first in the same container)
        # Default to the same directories as scripts/test.sh (exclude integration tests)
        if path is None:
            path = [
                "test/core", "test/data", "test/domain",
                "test/presentation", "test/helpers"
            ]

        params = {k: v for k, v in args.items() if v is not None}

        if async_mode:
            run_id = self.cache.reserve_run_id("test", params)

            async def _run_background():
                cidfile = None
                try:
                    args = ["test", "--reporter", "compact"]
                    if path:
                        if isinstance(path, list):
                            args.extend(path)
                        else:
                            args.append(path)
                    if name:
                        args.extend(["--name", name])
                    if fail_fast:
                        args.append("--fail-fast")
                    if coverage:
                        args.append("--coverage")

                    proc, cidfile = self.runner.start_flutter_command(
                        args,
                        with_pub_get=True,
                        capture_output=True
                    )
                    self.running_procs[run_id] = proc
                    self.cache.update_pending(run_id, {"pid": proc.pid, "cidfile": cidfile})
                    if cidfile:
                        container_id = self.runner._read_cidfile(cidfile)
                        if container_id:
                            self.cache.update_pending(run_id, {"containerId": container_id})

                    stdout_bytes, stderr_bytes = proc.communicate(timeout=timeout)
                    stdout = stdout_bytes.decode() if stdout_bytes else ""
                    stderr = stderr_bytes.decode() if stderr_bytes else ""
                    output = stdout + stderr
                    if run_id in self.cancelled_runs:
                        return
                    result = self.test_parser.parse(output)
                    result.summary.duration = time.time() - start_time
                    self.cache.store_test_result(result, params, output, run_id=run_id)
                except subprocess.TimeoutExpired:
                    if run_id in self.running_procs:
                        self.running_procs[run_id].kill()
                    result = TestResult(
                        success=False,
                        summary=TestSummary(total=0, failed=1),
                        warnings=[f"Async test run timed out after {timeout}s"],
                        runId=run_id
                    )
                    self.cache.store_test_result(result, params, "", run_id=run_id)
                except Exception as e:
                    result = TestResult(
                        success=False,
                        summary=TestSummary(total=0, failed=1),
                        warnings=[f"Async test run failed: {e}"],
                        runId=run_id
                    )
                    self.cache.store_test_result(result, params, str(e), run_id=run_id)
                finally:
                    if run_id in self.running_procs:
                        del self.running_procs[run_id]
                    if run_id in self.cancelled_runs:
                        self.cancelled_runs.remove(run_id)
                    if cidfile:
                        try:
                            os.unlink(cidfile)
                        except OSError:
                            pass

            asyncio.create_task(_run_background())

            return {
                "status": "running",
                "runId": run_id,
                "message": "Test run started in background. Poll get_run_status or get_test_results."
            }

        returncode, stdout, stderr = self.runner.test(
            path=path,
            name=name,
            fail_fast=fail_fast,
            coverage=coverage,
            reporter="compact",
            timeout=timeout
        )

        output = stdout + stderr
        result = self.test_parser.parse(output)
        result.summary.duration = time.time() - start_time
        self.cache.store_test_result(result, params, output)

        return asdict(result)

    async def _flutter_analyze(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute flutter analyze command."""
        # Extract parameters
        path = args.get("path")
        timeout = args.get("timeout", 120)
        min_severity = args.get("severity", "info")
        max_issues = args.get("maxIssues", 50)
        async_mode = args.get("async", True)

        # Update Docker image if specified
        if args.get("dockerImage"):
            self.runner.docker_image = args["dockerImage"]

        # Run analyze (pub get is automatically run first in the same container)
        params = {k: v for k, v in args.items() if v is not None}

        if async_mode:
            run_id = self.cache.reserve_run_id("analyze", params)

            async def _run_background():
                cidfile = None
                try:
                    args = ["analyze"]
                    if path:
                        args.append(path)

                    proc, cidfile = self.runner.start_flutter_command(
                        args,
                        with_pub_get=True,
                        capture_output=True
                    )
                    self.running_procs[run_id] = proc
                    self.cache.update_pending(run_id, {"pid": proc.pid, "cidfile": cidfile})
                    if cidfile:
                        container_id = self.runner._read_cidfile(cidfile)
                        if container_id:
                            self.cache.update_pending(run_id, {"containerId": container_id})

                    stdout_bytes, stderr_bytes = proc.communicate(timeout=timeout)
                    stdout = stdout_bytes.decode() if stdout_bytes else ""
                    stderr = stderr_bytes.decode() if stderr_bytes else ""
                    output = stdout + stderr
                    if run_id in self.cancelled_runs:
                        return
                    result = self.analyze_parser.parse(output)
                    self.cache.store_analyze_result(result, params, output, run_id=run_id)
                except subprocess.TimeoutExpired:
                    if run_id in self.running_procs:
                        self.running_procs[run_id].kill()
                    result = AnalyzeResult(
                        success=False,
                        summary=AnalyzeSummary(errors=1),
                        issues=None,
                        runId=run_id
                    )
                    self.cache.store_analyze_result(result, params, "", run_id=run_id)
                except Exception as e:
                    result = AnalyzeResult(
                        success=False,
                        summary=AnalyzeSummary(errors=1),
                        issues=None,
                        runId=run_id
                    )
                    self.cache.store_analyze_result(result, params, str(e), run_id=run_id)
                finally:
                    if run_id in self.running_procs:
                        del self.running_procs[run_id]
                    if run_id in self.cancelled_runs:
                        self.cancelled_runs.remove(run_id)
                    if cidfile:
                        try:
                            os.unlink(cidfile)
                        except OSError:
                            pass

            asyncio.create_task(_run_background())

            return {
                "status": "running",
                "runId": run_id,
                "message": "Analyze started in background. Poll get_run_status or get_analyze_results."
            }

        returncode, stdout, stderr = self.runner.analyze(
            path=path,
            timeout=timeout
        )

        output = stdout + stderr
        result = self.analyze_parser.parse(output)

        # Filter by severity if requested
        if result.issues and min_severity != "info":
            severity_order = {"error": 3, "warning": 2, "info": 1, "hint": 0}
            min_level = severity_order.get(min_severity, 0)
            result.issues = [
                issue for issue in result.issues
                if severity_order.get(issue.severity, 0) >= min_level
            ]

        # Store FULL result in cache (before limiting for response)
        self.cache.store_analyze_result(result, params, output)

        # Limit issues in response (but keep full data in cache)
        result_dict = asdict(result)
        if max_issues > 0 and result.issues and len(result.issues) > max_issues:
            total_issues = len(result.issues)
            result_dict['issues'] = result_dict['issues'][:max_issues]
            result_dict['truncated'] = True
            result_dict['total_issues'] = total_issues
            result_dict['showing_issues'] = max_issues
            result_dict['message'] = f"Showing first {max_issues} of {total_issues} issues. Use maxIssues=0 to see all or get_analyze_results to query cache."

        return result_dict

    async def _flutter_build(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute flutter build command."""
        start_time = time.time()

        # Extract parameters
        target = args["target"]
        mode = args.get("mode", "debug")
        flavor = args.get("flavor")
        build_number = args.get("buildNumber")
        build_name = args.get("buildName")
        dart_defines = args.get("dartDefines", {})
        timeout = args.get("timeout", 1200)
        async_mode = args.get("async", True)

        # Update Docker image if specified
        if args.get("dockerImage"):
            self.runner.docker_image = args["dockerImage"]

        # Run build (pub get is automatically run first in the same container)
        params = {k: v for k, v in args.items() if v is not None}

        if async_mode:
            run_id = self.cache.reserve_run_id("build", params)

            async def _run_background():
                cidfile = None
                try:
                    args = ["build", target]
                    if mode != "debug":
                        args.append(f"--{mode}")
                    if flavor:
                        args.extend(["--flavor", flavor])
                    if build_number:
                        args.extend(["--build-number", build_number])
                    if build_name:
                        args.extend(["--build-name", build_name])
                    # Add --dart-define flags
                    for key, value in dart_defines.items():
                        args.extend(["--dart-define", f"{key}={value}"])

                    proc, cidfile = self.runner.start_flutter_command(
                        args,
                        with_pub_get=True,
                        capture_output=True
                    )
                    self.running_procs[run_id] = proc
                    self.cache.update_pending(run_id, {"pid": proc.pid, "cidfile": cidfile})
                    if cidfile:
                        container_id = self.runner._read_cidfile(cidfile)
                        if container_id:
                            self.cache.update_pending(run_id, {"containerId": container_id})

                    stdout_bytes, stderr_bytes = proc.communicate(timeout=timeout)
                    stdout = stdout_bytes.decode() if stdout_bytes else ""
                    stderr = stderr_bytes.decode() if stderr_bytes else ""
                    output = stdout + stderr
                    success = proc.returncode == 0
                    if run_id in self.cancelled_runs:
                        return
                    result = self.build_parser.parse(output, success)
                    result.duration = time.time() - start_time
                    self.cache.store_build_result(result, params, output, run_id=run_id)
                except subprocess.TimeoutExpired:
                    if run_id in self.running_procs:
                        self.running_procs[run_id].kill()
                    result = BuildResult(
                        success=False,
                        output=f"Async build timed out after {timeout}s",
                        errors=[BuildError(message=f"Async build timed out after {timeout}s")]
                    )
                    self.cache.store_build_result(result, params, "", run_id=run_id)
                except Exception as e:
                    result = BuildResult(
                        success=False,
                        output=str(e),
                        errors=[BuildError(message=f"Async build failed: {e}")]
                    )
                    self.cache.store_build_result(result, params, str(e), run_id=run_id)
                finally:
                    if run_id in self.running_procs:
                        del self.running_procs[run_id]
                    if run_id in self.cancelled_runs:
                        self.cancelled_runs.remove(run_id)
                    if cidfile:
                        try:
                            os.unlink(cidfile)
                        except OSError:
                            pass

            asyncio.create_task(_run_background())

            return {
                "status": "running",
                "runId": run_id,
                "message": "Build started in background. Poll get_run_status or get_build_results."
            }

        returncode, stdout, stderr = self.runner.build(
            target=target,
            mode=mode,
            flavor=flavor,
            build_number=build_number,
            build_name=build_name,
            dart_defines=dart_defines,
            timeout=timeout
        )

        output = stdout + stderr
        success = returncode == 0
        result = self.build_parser.parse(output, success)
        result.duration = time.time() - start_time
        self.cache.store_build_result(result, params, output)

        return asdict(result)

    async def _get_test_results(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Get cached test results."""
        import re

        run_id = args.get("runId")
        failed_only = args.get("failedOnly", False)
        file_filter = args.get("file")
        search_message = args.get("searchMessage")
        exclude_pattern = args.get("excludePattern")
        max_failures = args.get("maxFailures", 50)

        result = self.cache.get_test_result(run_id)
        if not result:
            return {"error": "No test results found"}

        # Work with a copy of failures to avoid modifying the cached object
        failures = result.failures if isinstance(result.failures, list) else []
        original_count = len(failures) if failures else 0

        # Apply filters to the copy
        if failures:
            # File filter
            if file_filter:
                failures = [
                    f for f in failures
                    if file_filter in f.file
                ]

            # Search message filter
            if search_message:
                failures = [
                    f for f in failures
                    if search_message.lower() in f.message.lower()
                ]

            # Exclude pattern (regex)
            if exclude_pattern:
                try:
                    pattern = re.compile(exclude_pattern)
                    failures = [
                        f for f in failures
                        if not pattern.search(f.message)
                    ]
                except re.error:
                    return {"error": f"Invalid regex pattern: {exclude_pattern}"}

        # Build result dict manually, ensuring all lists are never None
        result_dict = {
            'success': result.success,
            'summary': {
                'passed': result.summary.passed,
                'failed': result.summary.failed,
                'skipped': result.summary.skipped,
                'total': result.summary.total,
                'duration': result.summary.duration,
            },
            'failures': [asdict(f) for f in (failures or [])] if failures else [],
            'skipped': [asdict(s) for s in (result.skipped or [])] if result.skipped else [],
            'warnings': result.warnings if isinstance(result.warnings, list) else [],
            'coveragePercent': result.coveragePercent,
            'runId': result.runId,
            'timestamp': str(result.timestamp),
        }
        filtered_count = len(failures) if failures else 0

        # Apply max_failures limit to the response
        if max_failures > 0 and filtered_count > max_failures:
            result_dict['failures'] = result_dict['failures'][:max_failures]
            result_dict['truncated'] = True
            result_dict['total_failures'] = original_count
            result_dict['filtered_failures'] = filtered_count
            result_dict['showing_failures'] = max_failures
            result_dict['message'] = f"Showing {max_failures} of {filtered_count} filtered failures (total: {original_count})"
        elif filtered_count < original_count:
            result_dict['filtered'] = True
            result_dict['total_failures'] = original_count
            result_dict['showing_failures'] = filtered_count
            result_dict['message'] = f"Showing {filtered_count} of {original_count} failures after filtering"

        return result_dict

    async def _get_build_results(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Get cached build results."""
        run_id = args.get("runId")
        result = self.cache.get_build_result(run_id)
        if not result:
            return {"error": "No build results found"}

        return asdict(result)

    async def _get_validation_results(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Get cached validation results."""
        run_id = args.get("runId")
        result = self.cache.get_validation_result(run_id)
        if not result:
            return {"error": "No validation results found"}

        return asdict(result)

    async def _cancel_run(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Cancel a running async operation."""
        run_id = args.get("runId", "")
        status = self.cache.get_status(run_id)
        if status.get("status") != "running":
            return status

        meta = self.cache.pending.get(run_id, {})
        operation = meta.get("operation", "unknown")
        container_id = meta.get("containerId")

        # Kill docker container if known
        if container_id:
            self.runner.kill_container_id(container_id)

        # Kill local process if tracked
        proc = self.running_procs.get(run_id)
        if proc:
            try:
                proc.kill()
            except Exception:
                pass

        # Prevent background tasks from overwriting cancellation result
        self.cancelled_runs.add(run_id)

        # Store a minimal cancelled result
        if operation == "test":
            result = TestResult(
                success=False,
                summary=TestSummary(total=0, failed=1),
                warnings=["Cancelled by user"],
                runId=run_id
            )
            self.cache.store_test_result(result, meta.get("params", {}), "Cancelled by user", run_id=run_id)
        elif operation == "analyze":
            result = AnalyzeResult(
                success=False,
                summary=AnalyzeSummary(errors=1),
                issues=None,
                runId=run_id
            )
            self.cache.store_analyze_result(result, meta.get("params", {}), "Cancelled by user", run_id=run_id)
        elif operation == "build":
            result = BuildResult(
                success=False,
                output="Cancelled by user",
                errors=[BuildError(message="Cancelled by user")]
            )
            self.cache.store_build_result(result, meta.get("params", {}), "Cancelled by user", run_id=run_id)
        elif operation == "validation":
            result = ValidationResult(
                success=False,
                analyze=AnalyzeResult(
                    success=False,
                    summary=AnalyzeSummary(errors=1),
                    issues=None
                ),
                test=None,
                duration=0.0
            )
            self.cache.store_validation_result(result, meta.get("params", {}), "Cancelled by user", run_id=run_id)

        return {"status": "cancelled", "runId": run_id, "operation": operation}

    async def _get_analyze_results(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Get cached analyze results."""
        import re

        run_id = args.get("runId")
        severity_filter = args.get("severity")
        file_filter = args.get("file")
        search_message = args.get("searchMessage")
        exclude_pattern = args.get("excludePattern")
        unique_types = args.get("uniqueTypes", False)
        max_issues = args.get("maxIssues", 50)

        result = self.cache.get_analyze_result(run_id)
        if not result:
            return {"error": "No analyze results found"}

        # Work with a copy of issues to avoid modifying the cached object
        issues = result.issues if isinstance(result.issues, list) else []
        original_count = len(issues) if issues else 0

        # Apply filters to the copy
        if issues:
            # Severity filter
            if severity_filter:
                severity_order = {"error": 3, "warning": 2, "info": 1, "hint": 0}
                min_level = severity_order.get(severity_filter, 0)
                issues = [
                    issue for issue in issues
                    if severity_order.get(issue.severity, 0) >= min_level
                ]

            # File filter
            if file_filter:
                issues = [
                    issue for issue in issues
                    if file_filter in issue.file
                ]

            # Search message filter
            if search_message:
                issues = [
                    issue for issue in issues
                    if search_message.lower() in issue.message.lower()
                ]

            # Exclude pattern (regex)
            if exclude_pattern:
                try:
                    pattern = re.compile(exclude_pattern)
                    issues = [
                        issue for issue in issues
                        if not pattern.search(issue.message)
                    ]
                except re.error:
                    return {"error": f"Invalid regex pattern: {exclude_pattern}"}

            # Deduplicate by type
            if unique_types:
                seen_types = set()
                unique_issues = []
                for issue in issues:
                    if issue.type not in seen_types:
                        seen_types.add(issue.type)
                        unique_issues.append(issue)
                issues = unique_issues

        # Build result dict manually, ensuring all lists are never None
        result_dict = {
            'success': result.success,
            'summary': {
                'errors': result.summary.errors,
                'warnings': result.summary.warnings,
                'infos': result.summary.infos,
                'hints': result.summary.hints,
            },
            'issues': [asdict(issue) for issue in (issues or [])] if issues else [],
            'runId': result.runId,
            'timestamp': str(result.timestamp),
        }
        filtered_count = len(issues) if issues else 0

        # Apply max_issues limit to the response
        if max_issues > 0 and filtered_count > max_issues:
            result_dict['issues'] = result_dict['issues'][:max_issues]
            result_dict['truncated'] = True
            result_dict['total_issues'] = original_count
            result_dict['filtered_issues'] = filtered_count
            result_dict['showing_issues'] = max_issues
            result_dict['message'] = f"Showing {max_issues} of {filtered_count} filtered issues (total: {original_count})"
        elif filtered_count < original_count:
            result_dict['filtered'] = True
            result_dict['total_issues'] = original_count
            result_dict['showing_issues'] = filtered_count
            result_dict['message'] = f"Showing {filtered_count} of {original_count} issues after filtering"

        return result_dict

    async def _run_validation(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Run both analyze and test."""
        start_time = time.time()

        stop_on_analyze_failure = args.get("stopOnAnalyzeFailure", True)
        test_options = args.get("testOptions", {})
        async_mode = args.get("async", True)

        # Run analyze
        analyze_args = {}
        if args.get("dockerImage"):
            analyze_args["dockerImage"] = args["dockerImage"]

        if async_mode:
            params = {k: v for k, v in args.items() if v is not None}
            run_id = self.cache.reserve_run_id("validation", params)

            async def _run_background():
                try:
                    # Analyze phase
                    self.cache.update_pending(run_id, {"phase": "analyze"})
                    analyze_args_list = ["analyze"]
                    proc, cidfile = self.runner.start_flutter_command(
                        analyze_args_list,
                        with_pub_get=True,
                        capture_output=True
                    )
                    self.running_procs[run_id] = proc
                    self.cache.update_pending(run_id, {"pid": proc.pid, "cidfile": cidfile})
                    if cidfile:
                        container_id = self.runner._read_cidfile(cidfile)
                        if container_id:
                            self.cache.update_pending(run_id, {"containerId": container_id})

                    stdout_bytes, stderr_bytes = proc.communicate(timeout=120)
                    if run_id in self.cancelled_runs:
                        return
                    stdout = stdout_bytes.decode() if stdout_bytes else ""
                    stderr = stderr_bytes.decode() if stderr_bytes else ""
                    analyze_output = stdout + stderr
                    analyze_result = self.analyze_parser.parse(analyze_output)
                    if cidfile:
                        try:
                            os.unlink(cidfile)
                        except OSError:
                            pass

                    test_result = None
                    if not stop_on_analyze_failure or analyze_result.success:
                        # Test phase
                        self.cache.update_pending(run_id, {"phase": "test"})
                        test_args = {**test_options}
                        if args.get("dockerImage"):
                            test_args["dockerImage"] = args["dockerImage"]

                        if 'path' not in test_args or test_args.get('path') is None:
                            test_args['path'] = [
                                'test/core', 'test/data', 'test/domain',
                                'test/presentation', 'test/helpers'
                            ]

                        test_args_list = ["test", "--reporter", "compact"]
                        path = test_args.get("path")
                        if path:
                            if isinstance(path, list):
                                test_args_list.extend(path)
                            else:
                                test_args_list.append(path)
                        if test_args.get("name"):
                            test_args_list.extend(["--name", test_args["name"]])
                        if test_args.get("failFast"):
                            test_args_list.append("--fail-fast")
                        if test_args.get("coverage"):
                            test_args_list.append("--coverage")

                        proc, cidfile = self.runner.start_flutter_command(
                            test_args_list,
                            with_pub_get=True,
                            capture_output=True
                        )
                        self.running_procs[run_id] = proc
                        self.cache.update_pending(run_id, {"pid": proc.pid, "cidfile": cidfile})
                        if cidfile:
                            container_id = self.runner._read_cidfile(cidfile)
                            if container_id:
                                self.cache.update_pending(run_id, {"containerId": container_id})

                        stdout_bytes, stderr_bytes = proc.communicate(timeout=300)
                        if run_id in self.cancelled_runs:
                            return
                        stdout = stdout_bytes.decode() if stdout_bytes else ""
                        stderr = stderr_bytes.decode() if stderr_bytes else ""
                        test_output = stdout + stderr
                        test_result = self.test_parser.parse(test_output)
                        if cidfile:
                            try:
                                os.unlink(cidfile)
                            except OSError:
                                pass

                    duration = time.time() - start_time
                    success = analyze_result.success and (test_result is None or test_result.success)

                    validation_result = ValidationResult(
                        success=success,
                        analyze=analyze_result,
                        test=test_result,
                        duration=duration
                    )
                    self.cache.store_validation_result(validation_result, params, run_id=run_id)
                except subprocess.TimeoutExpired:
                    if run_id in self.running_procs:
                        self.running_procs[run_id].kill()
                    validation_result = ValidationResult(
                        success=False,
                        analyze=AnalyzeResult(
                            success=False,
                            summary=AnalyzeSummary(errors=1),
                            issues=None
                        ),
                        test=None,
                        duration=time.time() - start_time
                    )
                    self.cache.store_validation_result(validation_result, params, "Validation timed out", run_id=run_id)
                except Exception as e:
                    validation_result = ValidationResult(
                        success=False,
                        analyze=AnalyzeResult(
                            success=False,
                            summary=AnalyzeSummary(errors=1),
                            issues=None
                        ),
                        test=None,
                        duration=time.time() - start_time
                    )
                    self.cache.store_validation_result(validation_result, params, str(e), run_id=run_id)
                finally:
                    if run_id in self.running_procs:
                        del self.running_procs[run_id]
                    if run_id in self.cancelled_runs:
                        self.cancelled_runs.remove(run_id)

            asyncio.create_task(_run_background())

            return {
                "status": "running",
                "runId": run_id,
                "message": "Validation started in background. Poll get_run_status or get_validation_results."
            }

        analyze_result_dict = await self._flutter_analyze({**analyze_args, "async": False})
        # Reconstruct AnalyzeResult from dict (with nested objects)
        analyze_summary = AnalyzeSummary(**analyze_result_dict['summary']) if analyze_result_dict.get('summary') else AnalyzeSummary()
        analyze_issues = [AnalyzeIssue(**issue) for issue in analyze_result_dict['issues']] if analyze_result_dict.get('issues') else None
        analyze_result = AnalyzeResult(
            success=analyze_result_dict['success'],
            summary=analyze_summary,
            issues=analyze_issues,
            runId=analyze_result_dict.get('runId', ''),
            timestamp=analyze_result_dict.get('timestamp', datetime.now())
        )

        test_result = None
        if not stop_on_analyze_failure or analyze_result.success:
            test_args = {**test_options, "async": False}
            if args.get("dockerImage"):
                test_args["dockerImage"] = args["dockerImage"]

            if 'path' not in test_args or test_args.get('path') is None:
                test_args['path'] = [
                    'test/core', 'test/data', 'test/domain',
                    'test/presentation', 'test/helpers'
                ]

            test_result_dict = await self._flutter_test(test_args)
            # Reconstruct TestResult from dict (with nested objects)
            test_summary = TestSummary(**test_result_dict['summary']) if test_result_dict.get('summary') else TestSummary()
            test_failures = [TestFailure(**failure) for failure in test_result_dict['failures']] if test_result_dict.get('failures') else None
            test_skipped = [SkippedTest(**skip) for skip in test_result_dict['skipped']] if test_result_dict.get('skipped') else None
            test_result = TestResult(
                success=test_result_dict['success'],
                summary=test_summary,
                failures=test_failures,
                skipped=test_skipped,
                warnings=test_result_dict.get('warnings'),
                coveragePercent=test_result_dict.get('coveragePercent'),
                runId=test_result_dict.get('runId', ''),
                timestamp=test_result_dict.get('timestamp', datetime.now())
            )

        duration = time.time() - start_time
        success = analyze_result.success and (test_result is None or test_result.success)

        validation_result = ValidationResult(
            success=success,
            analyze=analyze_result,
            test=test_result,
            duration=duration
        )

        params = {k: v for k, v in args.items() if v is not None}
        self.cache.store_validation_result(validation_result, params)

        return asdict(validation_result)

    async def _flutter_pub(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Execute flutter pub command."""
        command = args["command"]
        timeout = args.get("timeout", 120)

        # Update Docker image if specified
        if args.get("dockerImage"):
            self.runner.docker_image = args["dockerImage"]

        # Run the appropriate pub command
        if command == "get":
            returncode, stdout, stderr = self.runner.pub_get(timeout=timeout)
        elif command == "upgrade":
            returncode, stdout, stderr = self.runner.pub_upgrade(timeout=timeout)
        elif command == "outdated":
            returncode, stdout, stderr = self.runner.pub_outdated(timeout=timeout)
        else:
            return {"success": False, "error": f"Unknown pub command: {command}"}

        output = stdout + stderr
        success = returncode == 0

        return {
            "success": success,
            "command": f"flutter pub {command}",
            "returncode": returncode,
            "output": output
        }

    async def _get_raw_log(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Get raw log output for a run (for debugging parser issues)."""
        run_id = args.get("runId")
        tail_lines = args.get("tail")
        head_lines = args.get("head")

        # If no run_id specified, get the latest test run
        if not run_id:
            latest_test = self.cache.get_test_result()
            if latest_test and latest_test.runId:
                run_id = latest_test.runId
            else:
                return {"error": "No run ID specified and no cached test results found"}

        # Get the log
        log = self.cache.get_log(run_id)
        if not log:
            return {
                "error": f"No log found for run ID: {run_id}",
                "hint": "Logs are stored for recent runs. Use list_test_runs to see available runs."
            }

        # Apply head/tail filters
        lines = log.split('\n')
        total_lines = len(lines)

        if head_lines and head_lines > 0:
            lines = lines[:head_lines]
        if tail_lines and tail_lines > 0:
            lines = lines[-tail_lines:]

        filtered_log = '\n'.join(lines)

        return {
            "runId": run_id,
            "totalLines": total_lines,
            "returnedLines": len(lines),
            "log": filtered_log
        }

    async def run(self):
        """Run the MCP server."""
        try:
            async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
                await self.server.run(
                    read_stream,
                    write_stream,
                    self.server.create_initialization_options()
                )
        finally:
            # Best-effort cleanup of any running jobs on shutdown
            for run_id in list(self.running_procs.keys()):
                try:
                    await self._cancel_run({"runId": run_id})
                except Exception:
                    pass


async def main():
    """Main entry point (async)."""
    import sys

    # Get project root from command line or use current directory
    project_root = sys.argv[1] if len(sys.argv) > 1 else None

    server = FlutterMCPServer(project_root=project_root)
    await server.run()


def cli():
    """CLI entry point (synchronous wrapper for script execution)."""
    asyncio.run(main())


if __name__ == "__main__":
    cli()
