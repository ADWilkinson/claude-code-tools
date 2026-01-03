# Claude Code Hooks

Hooks execute shell commands at specific points in Claude Code's lifecycle. They're useful for automating quality checks, formatting, and verification.

## Available Hooks

### auto-format.sh

Automatically formats code after Claude writes or edits files. Detects project type and runs the appropriate formatter:

- **TypeScript/JavaScript**: Prettier (project-local or global)
- **Python**: Ruff or Black
- **Solidity**: Forge fmt
- **Go**: gofmt
- **Rust**: rustfmt

## Installation

```bash
# Copy to your Claude hooks directory
mkdir -p ~/.claude/hooks
cp hooks/auto-format.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/auto-format.sh
```

Then add to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/auto-format.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook Types

Claude Code supports these hook events:

| Event | When it runs |
|-------|--------------|
| `SessionStart` | When a session starts or resumes |
| `PreToolUse` | Before a tool is executed |
| `PostToolUse` | After a tool completes |
| `UserPromptSubmit` | When user submits a prompt |
| `Stop` | When Claude stops (for verification) |

## Creating Custom Hooks

Hooks receive JSON input via stdin with context about the event. Example for `PostToolUse`:

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "old_string": "...",
    "new_string": "..."
  }
}
```

Your hook can:
- Return JSON with `"message"` to show feedback
- Return `"decision": "block"` to prevent tool execution (PreToolUse only)
- Exit silently (exit 0) for no-op

