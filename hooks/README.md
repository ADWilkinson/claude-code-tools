# Claude Code Hooks

Hooks execute shell commands at specific points in Claude Code's lifecycle. They're useful for automating quality checks, formatting, and verification.

If you install via `./install.sh`, the hook scripts are copied into `~/.claude/hooks/` but still need to be enabled in `settings.json`.

If you install the plugin, `hooks.json` in this directory wires both hooks up automatically. Claude Code runs hooks from your project directory, so the commands there address the scripts through `${CLAUDE_PLUGIN_ROOT}`, which it substitutes for the plugin directory. That variable is only available in a plugin's `hooks/hooks.json`, not in `settings.json`.

## Requirements

Both hooks parse Claude Code's JSON payload with [`jq`](https://jqlang.github.io/jq/), which ships with neither macOS nor most Linux distributions. Install it with `brew install jq` or `apt install jq`. Without `jq` the hooks exit successfully and do nothing rather than reporting an error on every tool call.

## Available Hooks

### auto-format.sh

Automatically formats code after Claude writes or edits files. Detects project type and runs the appropriate formatter:

- **TypeScript/JavaScript**: Prettier (project-local or global)
- **Python**: Ruff or Black
- **Solidity**: Forge fmt
- **Go**: gofmt
- **Rust**: rustfmt

### constraint-persistence.sh

Detects when users set persistent constraints (e.g., "from now on always use X") and prompts Claude to suggest saving the rule to CLAUDE.md.

Triggers on phrases like:
- "from now on"
- "always do" / "never do"
- "don't ever" / "stop doing" / "start doing"
- "going forward"

## Installation

```bash
# Copy to your Claude hooks directory
mkdir -p ~/.claude/hooks
cp hooks/auto-format.sh ~/.claude/hooks/
cp hooks/constraint-persistence.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
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
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/constraint-persistence.sh"
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
