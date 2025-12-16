# Configuring Flutter MCP Server with Claude Code

This guide explains how to configure the Flutter MCP Server for use with Claude Code.

## Prerequisites

1. **Python 3.10+** installed on your system
2. **[uv](https://github.com/astral-sh/uv)** - Fast Python package installer:
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
3. **Docker** (optional but recommended) for running Flutter commands

## Installation

### Install Dependencies with uv

```bash
cd /home/martin/code/repertoire-coach/flutter-mcp-server

# Install dependencies (uv creates venv automatically)
uv sync
```

That's it! `uv` automatically manages the virtual environment and installs all dependencies from `pyproject.toml`.

## Claude Code Configuration

Add the Flutter MCP server to your Claude Code configuration file.

### Location of Config File

The Claude Code MCP configuration file is typically located at:
- Linux: `~/.config/claude/mcp.json` or `~/.config/Code/User/globalStorage/anthropic.claude-code/mcp.json`
- macOS: `~/Library/Application Support/claude/mcp.json` or similar
- Windows: `%APPDATA%\claude\mcp.json`

You can also check the Claude Code settings to find the exact location.

### Configuration

Add this to your `mcp.json`:

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

**Important:** Adjust the paths:
- Last argument in `args`: Should point to your Flutter project root (where `pubspec.yaml` is)
- `cwd`: Should point to the `flutter-mcp-server` directory

Using `uv` simplifies the configuration - no need to manage Python interpreter paths!

## Verification

### 1. Test the Server Manually

You can test if the server starts correctly:

```bash
cd /home/martin/code/repertoire-coach/flutter-mcp-server
uv run python -m src /home/martin/code/repertoire-coach
```

The server should start and wait for MCP messages on stdin/stdout. Press Ctrl+C to exit.

### 2. Check Docker Availability

If you plan to use Docker mode (recommended):

```bash
docker --version
docker run --rm hello-world
```

### 3. Test in Claude Code

1. Restart Claude Code after updating the configuration
2. In a conversation, try using the MCP tools:
   - "Run the Flutter tests using the flutter_test tool"
   - "Analyze the code with flutter_analyze"
   - "Show me the latest test results from the test://latest resource"

## Usage Examples

Once configured, you can use the MCP server in Claude Code conversations:

### Running Tests

```
User: Run the Flutter tests for the widgets directory

Claude: I'll use the flutter_test MCP tool to run tests in the widgets directory.
[Claude calls flutter_test with path: "test/presentation/widgets/"]
```

### Getting Structured Results

```
User: What tests failed in the last run?

Claude: Let me check the cached test results.
[Claude calls get_test_results with failedOnly: true]
```

### Running Validation

```
User: Run the validation suite

Claude: I'll run both analyze and test using the run_validation tool.
[Claude calls run_validation]
```

### Accessing Resources

```
User: Show me the latest test results

Claude: I'll read the test://latest resource.
[Claude reads test://latest resource]
```

## Troubleshooting

### Server doesn't start

**Check uv installation:**
```bash
uv --version
```

If not installed: `curl -LsSf https://astral.sh/uv/install.sh | sh`

**Check MCP installation:**
```bash
cd /home/martin/code/repertoire-coach/flutter-mcp-server
uv run python -c "import mcp; print(mcp.__version__)"
```

If this fails, reinstall: `uv sync`

### Docker errors

**If you get "Docker not available":**
- Install Docker
- Or set `useDocker: false` in tool calls to use local Flutter

**Docker permission errors:**
```bash
sudo usermod -aG docker $USER
# Then log out and log back in
```

### Import errors

Make sure you're in the correct directory and dependencies are installed:
```bash
cd /home/martin/code/repertoire-coach/flutter-mcp-server
uv sync
uv run python -c "from src.server import FlutterMCPServer; print('OK')"
```

### Claude Code doesn't see the tools

1. Check the MCP configuration file path
2. Restart Claude Code completely
3. Check Claude Code logs for MCP server errors
4. Verify the server starts manually

## Advanced Configuration

### Custom Docker Image

The server is configured to use the `repertoire-coach-builder` Docker image by default. To use a different Flutter Docker image, modify `src/server.py` line 33:

```python
# In src/server.py __init__ method
self.runner = FlutterRunner(
    docker_enabled=True,
    docker_image="ghcr.io/cirruslabs/flutter:stable",  # Change this
    project_root=str(self.project_root)
)
```

Common alternatives:
- `ghcr.io/cirruslabs/flutter:stable` - Latest stable Flutter
- `ghcr.io/cirruslabs/flutter:3.16.0` - Specific Flutter version
- Your custom image with project dependencies pre-installed

### Multiple Projects

You can configure multiple Flutter projects:

```json
{
  "mcpServers": {
    "flutter-project1": {
      "command": "uv",
      "args": ["run", "python", "-m", "src", "/path/to/project1"],
      "cwd": "/home/martin/code/repertoire-coach/flutter-mcp-server"
    },
    "flutter-project2": {
      "command": "uv",
      "args": ["run", "python", "-m", "src", "/path/to/project2"],
      "cwd": "/home/martin/code/repertoire-coach/flutter-mcp-server"
    }
  }
}
```

## Environment Variables

The server respects these environment variables (if implemented):

- `FLUTTER_DOCKER_IMAGE`: Docker image to use (currently hardcoded to `repertoire-coach-builder`)
- `FLUTTER_PATH`: Path to local Flutter binary (if not using Docker)
- `MCP_LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)

## Key Behaviors

- **Automatic Dependency Installation**: The server automatically runs `flutter pub get` before each command (test, analyze, build) in the same Docker container. This ensures dependencies are always available and matches the behavior of the validation scripts.
- **Single Container Execution**: Commands like `flutter test` run in a single Docker container with pub get, not separate containers. This prevents the "0 tests" issue caused by missing dependencies.

## Security Notes

- The server executes Flutter commands, which can run arbitrary Dart code
- Only use with trusted Flutter projects
- Docker mode provides isolation from the host system
- Never run the server with elevated privileges unless necessary

## Support

For issues or questions:
1. Check the main README.md
2. Review the server logs
3. Test Flutter commands manually first
4. Check Claude Code MCP documentation

## Next Steps

After configuration:
1. Test with a simple tool call ("run flutter_test")
2. Check resource access ("show test://latest")
3. Try the validation workflow
4. Explore token savings in your workflows

The server is designed to dramatically reduce token usage when working with Flutter tests and builds. Enjoy!
