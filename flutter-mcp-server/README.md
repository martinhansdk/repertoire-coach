# Flutter MCP Server

An MCP (Model Context Protocol) server that provides structured, token-efficient access to Flutter/Dart test and build operations. Designed to reduce token usage by 60-80% when working with test-heavy workflows by returning compact structured data instead of raw console output.

## Features

- **Structured Results**: Returns JSON instead of raw Flutter output
- **Smart Caching**: Stores recent test/analyze/build results for quick queries
- **Docker Support**: Run Flutter commands in Docker containers (no local Flutter install needed)
- **Comprehensive Parsing**: Extracts failures, warnings, and metadata from Flutter output
- **Low Token Usage**: Reduces token consumption by ~96% compared to raw output
- **MCP Resources**: Access latest results via standardized resource URIs

## Installation

### Prerequisites

- Python 3.10 or higher
- [uv](https://github.com/astral-sh/uv) - Fast Python package installer
- Docker (optional, but recommended for consistent Flutter environment)

### Install with uv (Recommended)

```bash
# Install uv if you haven't already
curl -LsSf https://astral.sh/uv/install.sh | sh

# Navigate to the server directory
cd flutter-mcp-server

# Install dependencies (uv will create a virtual environment automatically)
uv sync
```

That's it! `uv` will automatically create a virtual environment and install all dependencies from `pyproject.toml`.

## Usage

### Running the Server

The server is designed to be run as an MCP server by Claude Code or other MCP clients:

```bash
# Using uv (recommended)
cd flutter-mcp-server
uv run python -m src /path/to/your/flutter/project
```

### Configuration with Claude Code

Add to your Claude Code MCP configuration (`~/.config/claude/mcp.json` or similar):

```json
{
  "mcpServers": {
    "flutter": {
      "command": "uv",
      "args": [
        "run",
        "python",
        "-m",
        "src",
        "/home/martin/code/repertoire-coach"
      ],
      "cwd": "/home/martin/code/repertoire-coach/flutter-mcp-server",
      "env": {}
    }
  }
}
```

**Note:** Adjust the last argument to point to your Flutter project root and the `cwd` to point to the flutter-mcp-server directory.

## Available Tools

### 1. `flutter_test`

Run Flutter tests with structured output.

**Parameters:**
- `path` (string, optional): Specific test file or directory
- `name` (string, optional): Filter by test name pattern
- `failFast` (boolean, optional): Stop on first failure
- `coverage` (boolean, optional): Generate coverage report
- `verbose` (boolean, optional): Include full output in cache
- `useDocker` (boolean, optional): Run in Docker container (default: true)
- `dockerImage` (string, optional): Docker image to use
- `timeout` (number, optional): Timeout in seconds

**Returns:**
```json
{
  "success": false,
  "summary": {
    "passed": 45,
    "failed": 2,
    "skipped": 3,
    "total": 50,
    "duration": 12.5
  },
  "failures": [
    {
      "test": "should display marker selection dialog",
      "file": "test/widgets/loop_control_test.dart",
      "line": 438,
      "error": "Found 2 widgets with text 'Create Loop'",
      "type": "assertion"
    }
  ],
  "runId": "test:20251210123045:a3f2c8d1"
}
```

### 2. `flutter_analyze`

Run Flutter analysis with structured errors.

**Parameters:**
- `path` (string, optional): Specific file/directory
- `severity` (string, optional): Minimum severity ("info", "warning", "error")
- `useDocker` (boolean, optional): Run in Docker container
- `timeout` (number, optional): Timeout in seconds

**Returns:**
```json
{
  "success": false,
  "summary": {
    "errors": 2,
    "warnings": 5,
    "infos": 3,
    "hints": 1
  },
  "issues": [
    {
      "severity": "error",
      "type": "undefined_identifier",
      "message": "Undefined name 'foo'",
      "file": "lib/main.dart",
      "line": 42,
      "column": 10
    }
  ],
  "runId": "analyze:20251210123050:b4e1d9f2"
}
```

### 3. `flutter_build`

Run Flutter build with structured output.

**Parameters:**
- `target` (string, required): Build target ("android", "ios", "web", "apk", "appbundle")
- `mode` (string, optional): Build mode ("debug", "profile", "release")
- `flavor` (string, optional): Build flavor
- `buildNumber` (string, optional): Build number
- `buildName` (string, optional): Build name
- `useDocker` (boolean, optional): Run in Docker container
- `timeout` (number, optional): Timeout in seconds

### 4. `get_test_results`

Query cached test results.

**Parameters:**
- `runId` (string, optional): Specific run ID (default: latest)
- `failedOnly` (boolean, optional): Only return failed tests
- `file` (string, optional): Filter by file

### 5. `get_analyze_results`

Query cached analysis results.

**Parameters:**
- `runId` (string, optional): Specific run ID (default: latest)
- `severity` (string, optional): Filter by severity
- `file` (string, optional): Filter by file

### 6. `run_validation`

Run both analyze and test (equivalent to `scripts/validate.sh`).

**Parameters:**
- `stopOnAnalyzeFailure` (boolean, optional): Don't run tests if analyze fails (default: true)
- `testOptions` (object, optional): Options passed to flutter_test
  - `path` (string, optional)
  - `failFast` (boolean, optional)
  - `coverage` (boolean, optional)
- `useDocker` (boolean, optional): Run in Docker container

**Returns:**
```json
{
  "success": false,
  "analyze": { /* AnalyzeResult */ },
  "test": { /* TestResult */ },
  "duration": 25.3
}
```

### 7. `list_test_runs`

List recent test runs with summaries.

**Returns:**
```json
[
  {
    "runId": "test:20251210123045:a3f2c8d1",
    "timestamp": "2025-12-10T12:30:45",
    "success": false,
    "summary": {
      "passed": 45,
      "failed": 2,
      "total": 50
    }
  }
]
```

## Available Resources

### `test://latest`
Latest test run results (JSON)

### `test://runs`
List of recent test run IDs with summaries

### `analyze://latest`
Latest analyze results (JSON)

### `build://latest`
Latest build results (JSON)

### `logs://test/{runId}`
Full test output log for specific run

### `logs://analyze/{runId}`
Full analyze output log for specific run

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

## Docker Integration

The server runs Flutter commands in Docker by default, which means:

✅ No local Flutter installation required
✅ Consistent Flutter environment across machines
✅ Isolated from host system
✅ Easy to update Flutter version

To disable Docker and use local Flutter:
```json
{
  "useDocker": false
}
```

## Examples

### Run Tests After Making Changes

```python
# Tool call
{
  "tool": "flutter_test",
  "arguments": {
    "path": "test/presentation/widgets/",
    "failFast": true
  }
}
```

### Quick Validation Check

```python
# Tool call
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

### Query Last Failed Tests

```python
# Tool call
{
  "tool": "get_test_results",
  "arguments": {
    "failedOnly": true
  }
}
```

### Access Latest Test Results (Resource)

```python
# Read resource
resource_uri = "test://latest"
```

## Architecture

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
│   └── models.py              # Data models
├── tests/
├── pyproject.toml
└── README.md
```

## Development

### Running Tests

```bash
pytest
```

### Code Quality

```bash
# Format code
black src/

# Lint
ruff check src/

# Type check
mypy src/
```

## License

MIT

## Contributing

Contributions welcome! Please ensure tests pass and code is formatted before submitting PRs.

## Troubleshooting

### Docker not found

If you get "Docker is not available", either:
1. Install Docker
2. Set `useDocker: false` to use local Flutter installation

### Flutter command timeout

Increase the timeout parameter:
```json
{
  "timeout": 600
}
```

### Cache not updating

The cache has a 1-hour TTL. To clear expired entries, restart the server.

## Future Enhancements

- [ ] Incremental testing (only run affected tests)
- [ ] Parallel test execution
- [ ] Test flakiness tracking
- [ ] Custom result filters
- [ ] Web dashboard for results
- [ ] CI/CD integration formats
