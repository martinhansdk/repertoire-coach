# Flutter Test & Build MCP Server Specification

## Overview

An MCP (Model Context Protocol) server that provides structured, token-efficient access to Flutter/Dart test and build operations. Designed to reduce token usage by 60-80% when working with test-heavy workflows by returning compact structured data instead of raw console output.

## Problem Statement

Current workflow issues:
- Running `flutter test` generates 40-100k characters of output per run
- Agents must grep/parse logs repeatedly to find specific errors
- High token usage analyzing test results, stack traces, and error messages
- Difficult to extract structured information from unstructured console output
- No caching of test results between operations

## Core Principles

1. **Return structured data, not raw output** - JSON responses with parsed results
2. **Provide smart filtering** - Only return what's needed (errors, specific tests, etc.)
3. **Cache results** - Store recent test/build results for quick queries
4. **Support incremental operations** - Run only affected tests, not full suite
5. **Work with Docker** - Support both native Flutter and Docker-based workflows

## Architecture

### Technology Stack
- **Language**: Python 3.10+ (matches MCP SDK requirements, easy JSON handling)
- **MCP SDK**: `@modelcontextprotocol/server-python`
- **Test Runner**: Wraps Flutter CLI (`flutter test`, `flutter analyze`, `flutter build`)
- **Parser**: Custom parsers for Flutter output formats
- **Cache**: In-memory with optional SQLite persistence

### Components

```
flutter-mcp-server/
├── src/
│   ├── server.py              # MCP server entry point
│   ├── flutter_runner.py      # Flutter CLI wrapper
│   ├── parsers/
│   │   ├── test_parser.py     # Parse flutter test output
│   │   ├── analyze_parser.py  # Parse flutter analyze output
│   │   └── build_parser.py    # Parse flutter build output
│   ├── cache.py               # Result caching
│   └── models.py              # Data models (TestResult, etc.)
├── tests/
├── pyproject.toml
└── README.md
```

## MCP Tools

### 1. `flutter_test`
Run Flutter tests with structured output.

**Parameters:**
```typescript
{
  path?: string;              // Specific test file or directory (default: all tests)
  name?: string;              // Filter by test name pattern
  failFast?: boolean;         // Stop on first failure (default: false)
  coverage?: boolean;         // Generate coverage report (default: false)
  verbose?: boolean;          // Include full output in cache (default: false)
  useDocker?: boolean;        // Run in Docker container (default: false)
  dockerImage?: string;       // Docker image (default: ghcr.io/cirruslabs/flutter:stable)
  timeout?: number;           // Timeout in seconds (default: 300)
}
```

**Returns:**
```typescript
{
  success: boolean;
  summary: {
    passed: number;
    failed: number;
    skipped: number;
    total: number;
    duration: number;         // seconds
  };
  failures?: Array<{
    test: string;             // Test name
    file: string;             // File path
    line?: number;            // Line number if available
    error: string;            // Error message
    stackTrace?: string[];    // Stack trace lines
    type: "timeout" | "assertion" | "exception" | "compilation";
  }>;
  skipped?: Array<{
    test: string;
    file: string;
    reason?: string;          // Skip reason if available
  }>;
  warnings?: string[];        // Non-fatal warnings
  coveragePercent?: number;   // If coverage enabled
  runId: string;              // Cache ID for this run
}
```

### 2. `flutter_analyze`
Run Flutter analysis with structured errors.

**Parameters:**
```typescript
{
  path?: string;              // Specific file/directory (default: entire project)
  severity?: "info" | "warning" | "error";  // Minimum severity (default: info)
  useDocker?: boolean;
  dockerImage?: string;
  timeout?: number;
}
```

**Returns:**
```typescript
{
  success: boolean;
  summary: {
    errors: number;
    warnings: number;
    infos: number;
    hints: number;
  };
  issues?: Array<{
    severity: "error" | "warning" | "info" | "hint";
    type: string;             // Issue code (e.g., "undefined_identifier")
    message: string;
    file: string;
    line: number;
    column: number;
    correction?: string;      // Suggested fix
  }>;
  runId: string;
}
```

### 3. `flutter_build`
Run Flutter build with structured output.

**Parameters:**
```typescript
{
  target: "android" | "ios" | "web" | "apk" | "appbundle";
  mode?: "debug" | "profile" | "release";  // default: debug
  flavor?: string;            // Build flavor
  buildNumber?: string;
  buildName?: string;
  useDocker?: boolean;
  dockerImage?: string;
  timeout?: number;           // default: 600 (10 min)
}
```

**Returns:**
```typescript
{
  success: boolean;
  output?: string;            // Build artifact path
  size?: number;              // Artifact size in bytes
  duration: number;           // seconds
  errors?: Array<{
    message: string;
    file?: string;
    line?: number;
  }>;
  warnings?: string[];
  runId: string;
}
```

### 4. `get_test_results`
Query cached test results.

**Parameters:**
```typescript
{
  runId?: string;             // Specific run (default: latest)
  failedOnly?: boolean;       // Only return failed tests (default: false)
  file?: string;              // Filter by file
}
```

**Returns:**
Same structure as `flutter_test` response, from cache.

### 5. `get_analyze_results`
Query cached analysis results.

**Parameters:**
```typescript
{
  runId?: string;             // Specific run (default: latest)
  severity?: "info" | "warning" | "error";  // Filter by severity
  file?: string;              // Filter by file
}
```

**Returns:**
Same structure as `flutter_analyze` response, from cache.

### 6. `run_validation`
Run both analyze and test (equivalent to scripts/validate.sh).

**Parameters:**
```typescript
{
  stopOnAnalyzeFailure?: boolean;  // Don't run tests if analyze fails (default: true)
  testOptions?: {              // Options passed to flutter_test
    path?: string;
    failFast?: boolean;
    coverage?: boolean;
  };
  useDocker?: boolean;
  dockerImage?: string;
}
```

**Returns:**
```typescript
{
  success: boolean;
  analyze: AnalyzeResult;     // Full analyze result
  test?: TestResult;          // Test result (null if skipped)
  duration: number;           // Total duration
}
```

### 7. `watch_tests`
Stream test results as they execute (long-running operation).

**Parameters:**
```typescript
{
  path?: string;
  name?: string;
  useDocker?: boolean;
}
```

**Returns:** Streaming results
```typescript
{
  type: "started" | "progress" | "completed" | "failed";
  test?: string;              // Current test name
  file?: string;
  passed?: number;            // Current pass count
  failed?: number;            // Current fail count
  message?: string;           // For progress/errors
}
```

### 8. `get_coverage`
Get coverage report for last test run.

**Parameters:**
```typescript
{
  runId?: string;             // Specific run (default: latest with coverage)
  format?: "summary" | "detailed" | "lcov";
  file?: string;              // Filter by specific file
}
```

**Returns:**
```typescript
{
  overall: {
    lines: number;            // Total lines
    covered: number;          // Covered lines
    percent: number;          // Coverage percentage
  };
  files?: Array<{
    path: string;
    lines: number;
    covered: number;
    percent: number;
    uncoveredLines?: number[];  // Line numbers not covered
  }>;
  lcov?: string;              // LCOV format data if requested
}
```

## MCP Resources

### 1. `test://latest`
Latest test run results (JSON).

### 2. `test://runs`
List of recent test run IDs with summaries.

### 3. `analyze://latest`
Latest analyze results (JSON).

### 4. `build://latest`
Latest build results (JSON).

### 5. `logs://test/{runId}`
Full test output log for specific run.

### 6. `logs://analyze/{runId}`
Full analyze output log for specific run.

## Implementation Details

### Parser Implementation

**Test Output Parser:**
- Parse compact test format: `00:05 +42 ~3 -1: test/path/file_test.dart: Group Test Name`
- Extract test names, files, pass/fail/skip counts
- Parse error messages and stack traces
- Handle compilation errors vs test failures
- Detect timeouts and hangs

**Analyze Output Parser:**
- Parse lint output format: `severity • message • file:line:column • code`
- Group by severity
- Extract suggested corrections from output
- Handle "No issues found" vs multiple issues

**Build Output Parser:**
- Parse build progress indicators
- Extract artifact paths and sizes
- Capture build errors and warnings
- Detect Gradle/Xcode errors

### Caching Strategy

**In-Memory Cache:**
- Store last 10 test runs
- Store last 5 analyze runs
- Store last 3 build runs
- TTL: 1 hour for test/analyze, 2 hours for builds

**Cache Key Structure:**
```
test:{timestamp}:{hash(params)}
analyze:{timestamp}:{hash(params)}
build:{timestamp}:{hash(params)}
```

**What to Cache:**
- Parsed structured results (always)
- Full console output (only if verbose=true or size < 100KB)
- Coverage data (if generated)
- Build artifacts metadata (not the actual files)

### Docker Integration

**Docker Mode:**
```bash
docker run --rm \
  -v {project_path}:/workspace \
  -w /workspace \
  {docker_image} \
  flutter test {args}
```

**Performance Optimization:**
- Reuse containers when possible
- Mount project as volume (don't copy)
- Stream output in real-time for watch mode
- Cache Docker image pulls

### Error Handling

**Timeout Handling:**
- Configurable timeouts per operation
- Graceful termination of hung processes
- Partial results if timeout occurs mid-test

**Parse Errors:**
- If parsing fails, fallback to raw output
- Log parse errors for debugging
- Include parse warnings in response

**Docker Errors:**
- Check Docker availability before use
- Provide helpful error messages ("Docker not found", "Container failed to start")
- Fallback to native Flutter if Docker fails (optional)

## Configuration

**Server Configuration** (`~/.config/flutter-mcp/config.json`):
```json
{
  "flutterPath": "/usr/local/bin/flutter",
  "dockerEnabled": true,
  "dockerImage": "ghcr.io/cirruslabs/flutter:stable",
  "cache": {
    "maxTestRuns": 10,
    "maxAnalyzeRuns": 5,
    "maxBuildRuns": 3,
    "ttlSeconds": 3600
  },
  "defaults": {
    "timeout": 300,
    "verbose": false,
    "coverage": false
  }
}
```

## Usage Examples

### Claude Code Integration

**1. Run tests after making changes:**
```json
{
  "tool": "flutter_test",
  "arguments": {
    "path": "test/presentation/widgets/",
    "failFast": true
  }
}
```

Response:
```json
{
  "success": false,
  "summary": {
    "passed": 45,
    "failed": 2,
    "skipped": 3,
    "total": 50
  },
  "failures": [
    {
      "test": "should display marker selection dialog",
      "file": "test/presentation/widgets/loop_control_buttons_test.dart",
      "line": 438,
      "error": "Found 2 widgets with text 'Create Loop'",
      "type": "assertion"
    }
  ]
}
```

**2. Quick validation check:**
```json
{
  "tool": "run_validation",
  "arguments": {
    "stopOnAnalyzeFailure": true,
    "testOptions": {
      "failFast": true
    }
  }
}
```

**3. Query last run for specific failures:**
```json
{
  "tool": "get_test_results",
  "arguments": {
    "failedOnly": true
  }
}
```

## Token Usage Comparison

### Before (Current Workflow)
```
1. Run test: 45,000 tokens (raw output)
2. Grep log: 15,000 tokens (filtered output)
3. Read errors: 8,000 tokens (error details)
Total: 68,000 tokens
```

### After (With MCP Server)
```
1. Run test: 2,000 tokens (structured result)
2. Query cache: 500 tokens (specific failures)
Total: 2,500 tokens
```

**Savings: 96% reduction in tokens**

## Development Roadmap

### Phase 1: Core Infrastructure (Week 1)
- [x] MCP server setup
- [x] Flutter CLI wrapper
- [x] Basic test parser
- [x] In-memory cache

### Phase 2: Core Tools (Week 2)
- [x] flutter_test tool
- [x] flutter_analyze tool
- [x] get_test_results tool
- [x] get_analyze_results tool

### Phase 3: Advanced Features (Week 3)
- [x] Docker integration
- [x] run_validation tool
- [x] Coverage support
- [x] Build tool

### Phase 4: Streaming & Resources (Week 4)
- [x] watch_tests streaming
- [x] MCP resources
- [x] Configuration file
- [x] Error handling improvements

### Phase 5: Polish & Documentation (Week 5)
- [x] Comprehensive testing
- [x] Documentation
- [x] Performance optimization
- [x] Release v1.0

## Testing Strategy

### Unit Tests
- Test parsers with fixture data (real Flutter output samples)
- Test cache operations (add, retrieve, eviction)
- Test Docker integration (mock Docker CLI)

### Integration Tests
- Run against real Flutter project
- Test all tools end-to-end
- Verify output structure
- Test error scenarios

### Performance Tests
- Measure parse time for large test suites
- Cache hit/miss ratios
- Memory usage with multiple cached runs

## Security Considerations

1. **Command Injection**: Sanitize all parameters passed to Flutter CLI
2. **Path Traversal**: Validate all file paths stay within project
3. **Resource Limits**: Limit cache size, timeout durations
4. **Docker Security**: Don't mount sensitive directories, use read-only when possible

## Future Enhancements

1. **Incremental Testing**: Only run tests affected by changed files
2. **Parallel Execution**: Run multiple test files in parallel
3. **Test History**: Track test flakiness over time
4. **Smart Retry**: Automatically retry flaky tests
5. **Web Dashboard**: Visual interface for test results
6. **Integration with CI**: Export results in CI-friendly formats
7. **Performance Profiling**: Track test execution times
8. **Custom Matchers**: Define custom test result filters

## References

- Flutter Test Documentation: https://flutter.dev/docs/testing
- MCP Specification: https://modelcontextprotocol.io/specification
- Flutter Test Output Format: https://github.com/flutter/flutter/tree/master/packages/flutter_test
