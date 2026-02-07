# Flutter MCP Server - Quick Start

Get the Flutter MCP Server running in 5 minutes!

## TL;DR

```bash
# 1. Install dependencies with uv
cd /home/martin/code/repertoire-coach/flutter-mcp-server
uv sync

# 2. Add to Claude Code config (~/.config/claude/mcp.json or similar)
{
  "mcpServers": {
    "flutter": {
      "command": "uv",
      "args": ["run", "python", "-m", "src", "/home/martin/code/repertoire-coach"],
      "cwd": "/home/martin/code/repertoire-coach/flutter-mcp-server"
    }
  }
}

# 3. Restart Claude Code

# 4. Test it!
# In Claude Code: "Run Flutter tests using the flutter_test tool"
```

## What This Does

This MCP server gives Claude Code superpowers for Flutter development:

✅ **Run Flutter tests** - Get structured results instead of 45K characters of output
✅ **Run Flutter analyze** - Structured error/warning data
✅ **Run Flutter build** - Build status and artifact info
✅ **Cache results** - Query previous runs without re-running
✅ **Use Docker** - No local Flutter install needed (optional)

**Token savings: ~96%** compared to reading raw Flutter output.

## Prerequisites

- Python 3.10+ (`python3 --version`)
- [uv](https://github.com/astral-sh/uv) - Fast Python package installer
- Docker (optional, for `useDocker: true` mode)
- Claude Code installed

## Step-by-Step Installation

### 1. Install uv and Dependencies

```bash
# Install uv (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Navigate to the server directory
cd /home/martin/code/repertoire-coach/flutter-mcp-server

# Install dependencies (uv creates venv and installs automatically)
uv sync
```

**Verify:**
```bash
uv run python -c "import mcp; print('MCP installed successfully')"
```

### 2. Configure Codex CLI (Recommended)

If you're using Codex CLI, add the MCP server directly (no config file editing):

```bash
codex mcp add flutter -- \
  uv run --directory /home/martin/code/repertoire-coach/flutter-mcp-server \
  flutter-mcp-server /home/martin/code/repertoire-coach
```

Verify:
```bash
codex mcp list
```

Restart Codex after adding the server.

### 3. Find Your Claude Code MCP Config File

Typical locations:
- **Linux:** `~/.config/claude/mcp.json` or `~/.config/Code/User/globalStorage/anthropic.claude-code/mcp.json`
- **macOS:** `~/Library/Application Support/claude/mcp.json`
- **Windows:** `%APPDATA%\claude\mcp.json`

If unsure, check Claude Code settings for "MCP Configuration Path".

### 4. Add Flutter MCP Server to Config

Edit your `mcp.json` file and add:

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

**Important:**
- Replace `/home/martin/code/repertoire-coach` with your Flutter project's root directory
- Replace `/home/martin/code/repertoire-coach/flutter-mcp-server` with the path to this server

If you have other MCP servers configured, just add the `"flutter"` entry to the existing `mcpServers` object.

### 5. Restart Claude Code

Completely close and reopen Claude Code to load the new MCP server.

### 6. Test It!

Open a conversation in Claude Code and try:

**Example 1: Run tests**
```
You: Run the Flutter tests in the widgets directory

Claude: I'll use the flutter_test tool to run tests in the widgets directory.
[Claude uses flutter_test MCP tool]
```

**Example 2: Check for errors**
```
You: Run Flutter analyze on the codebase

Claude: I'll use the flutter_analyze tool.
[Claude uses flutter_analyze MCP tool]
```

**Example 3: Get cached results**
```
You: What tests failed in the last run?

Claude: I'll query the cached test results.
[Claude uses get_test_results with failedOnly: true]
```

## Verification Checklist

- [ ] Python 3.10+ installed (`python3 --version`)
- [ ] uv installed (`uv --version`)
- [ ] Dependencies installed (`uv sync` completed successfully)
- [ ] MCP package available (`uv run python -c "import mcp"`)
- [ ] Claude Code MCP config file found and updated
- [ ] Flutter project path in config is correct
- [ ] Server directory path in config is correct
- [ ] Claude Code restarted
- [ ] Test tool call works in conversation

## Common Issues

### "Module mcp not found"

```bash
# Install dependencies with uv
cd /home/martin/code/repertoire-coach/flutter-mcp-server
uv sync
```

### "Docker not available" (when using useDocker: true)

```bash
# Check Docker
docker --version

# If not installed, either:
# 1. Install Docker, or
# 2. Use useDocker: false in tool calls to use local Flutter
```

### Claude doesn't recognize the tools

1. Check MCP config file path is correct
2. Restart Claude Code completely (not just reload)
3. Check server starts manually:
   ```bash
   cd /home/martin/code/repertoire-coach/flutter-mcp-server
   uv run python -m src /home/martin/code/repertoire-coach
   # Should wait for input (Ctrl+C to exit)
   ```

### "uv: command not found"

Install uv:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# Then restart your shell or run: source ~/.bashrc (or ~/.zshrc)
```

## What's Next?

### Try These Workflows

1. **Test-Driven Development:**
   - "Run tests for the audio player"
   - "What failed? Show me the errors"
   - [Fix the code]
   - "Run tests again"

2. **Code Quality:**
   - "Run analyze and show me errors only"
   - [Fix issues]
   - "Run full validation"

3. **Build Verification:**
   - "Build the Android APK in debug mode"
   - "What's the output path?"

### Explore the Tools

- `flutter_test` - Run tests with filters and options
- `flutter_analyze` - Lint and analyze code
- `flutter_build` - Build for different platforms
- `run_validation` - Analyze + test combo
- `get_test_results` - Query cached test runs
- `get_analyze_results` - Query cached analyze runs
- `list_test_runs` - See recent test history

### Explore the Resources

- `test://latest` - Latest test results
- `analyze://latest` - Latest analyze results
- `build://latest` - Latest build results
- `test://runs` - List of all test runs
- `logs://test/{runId}` - Full log for specific run

## Benefits You'll See

**Before (without MCP server):**
```
User: Run the tests
Claude: [Runs `docker run ... flutter test`]
        [Receives 45,000 characters of output]
        [Parses output manually]
        [Uses ~45K tokens]
User: What failed?
Claude: [Re-reads the huge output]
        [Uses another ~15K tokens]
Total: ~60,000 tokens
```

**After (with MCP server):**
```
User: Run the tests
Claude: [Calls flutter_test MCP tool]
        [Receives structured JSON ~2,000 chars]
        [Uses ~2K tokens]
User: What failed?
Claude: [Calls get_test_results with failedOnly: true]
        [Receives only failures]
        [Uses ~500 tokens]
Total: ~2,500 tokens
```

**Savings: 96%!**

## Documentation

- Full documentation: [README.md](README.md)
- Configuration guide: [CLAUDE_CONFIG.md](CLAUDE_CONFIG.md)
- Specification: [../docs/FLUTTER_MCP_SERVER.md](../docs/FLUTTER_MCP_SERVER.md)

## Support

Having issues? Check:
1. This QUICKSTART.md
2. The full [README.md](README.md)
3. [CLAUDE_CONFIG.md](CLAUDE_CONFIG.md) troubleshooting section
4. Server logs (if Claude provides them)

## Success!

If you've made it this far and tested a tool call successfully, congratulations! You now have a super-powered Flutter development workflow with Claude Code.

Happy coding! 🎵🎯
