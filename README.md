# Claude Code Tools

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub last commit](https://img.shields.io/github/last-commit/ADWilkinson/claude-code-tools)](https://github.com/ADWilkinson/claude-code-tools/commits/main)
[![GitHub stars](https://img.shields.io/github/stars/ADWilkinson/claude-code-tools?style=social)](https://github.com/ADWilkinson/claude-code-tools)

Custom agents, commands, skills, hooks, and statusline for [Claude Code](https://github.com/anthropics/claude-code).

## Quick Install

```bash
git clone https://github.com/ADWilkinson/claude-code-tools.git
cd claude-code-tools
./install.sh
```

Default install includes agents, commands, skills, hooks, and statusline. The Linear skill will install its dependencies if `npm` is available; hooks still need `settings.json` configuration.

## What's Included

### Agents (16)

Specialized subagents invoked automatically by Claude Code's Task tool:

| Agent | Description |
|-------|-------------|
| `backend-developer` | Express/Node.js, REST APIs, authentication, webhooks |
| `blockchain-specialist` | Solidity, Wagmi, multi-chain, gas optimization |
| `code-simplifier` | Remove over-engineering, dead code, verbose patterns |
| `database-manager` | PostgreSQL, Prisma ORM, query optimization |
| `debugger` | Root cause analysis, error tracing, systematic debugging |
| `devops-engineer` | CI/CD, Docker, GitHub Actions, cloud deployment |
| `extension-developer` | Chrome Manifest V3, service workers, messaging |
| `firebase-specialist` | Firestore, Cloud Functions, FCM, security rules |
| `frontend-developer` | React, Next.js, TanStack Query, Tailwind |
| `indexer-developer` | Envio, The Graph, GraphQL, event handlers |
| `mcp-developer` | MCP servers, tool definitions, LLM integrations |
| `mobile-developer` | React Native, Expo, biometrics, push notifications |
| `performance-engineer` | Profiling, caching, load testing, optimization |
| `refactoring-specialist` | Code smells, safe transformations, complexity reduction |
| `testing-specialist` | Jest, Playwright, E2E, mocking strategies |
| `zk-specialist` | ZK circuits, Circom/Noir, trusted setup |

All agents use **opus** model for maximum capability.

### Skills (2)

Auto-invoked skills that Claude applies when relevant:

| Skill | Trigger | Description |
|-------|---------|-------------|
| `linear` | "tasks", "issues", "Linear" | Full Linear task management - view, search, create, update issues |
| `verify-changes` | After implementing features | Run tests, builds, checks to verify code works |

**Linear Skill Features:**
- `my-tasks` / `backlog` / `in-progress` / `team-tasks` - View issues by state
- `search "query"` - Search title and description
- `--label NAME` - Filter any list by label
- `create` / `start` / `done` / `show` / `comment` - Issue actions

**Setup:**
```bash
cd skills/linear && ./install.sh
export LINEAR_API_KEY="lin_api_..."  # Add to ~/.zshrc
```

Then just talk naturally: "show my tasks", "search rebrand issues", "mark ENG-123 done"

**verify-changes**: Auto-detects project type and runs appropriate verification (typecheck, lint, test, build). Provides the feedback loop that 2-3x code quality.

### Commands (4)

Slash commands for common workflows:

- `/repo-polish` - Fire-and-forget repository cleanup. Creates a branch, fixes issues, opens a PR.
- `/update-claudes` - Generates CLAUDE.md files throughout your project for AI context.
- `/minimize-ui` - Systematic UI minimalization through ruthless reduction. 7-phase workflow that removes before polishing.
- `/generate-precommit-hooks` - Detect project type and set up appropriate pre-commit hooks (husky, lint-staged, etc.).

### Statusline

Custom statusline showing:
- Current directory and git branch
- Activity icons for active tools
- Cumulative cost tracking
- Code diff stats (+/- lines)

### Hooks (2)

Shell scripts that run at specific points in Claude Code's lifecycle:

- `auto-format.sh` - PostToolUse hook that runs formatters after Claude writes code. Supports Prettier, Ruff, gofmt, rustfmt, forge fmt.
- `constraint-persistence.sh` - UserPromptSubmit hook that detects when you set rules ("from now on", "always do X") and prompts Claude to save them to CLAUDE.md.

Install copies hooks to `~/.claude/hooks`, but you still need to add them to `settings.json`. See [hooks/README.md](hooks/README.md) for setup instructions.

### Rules (1)

Reusable rule files for `~/.claude/rules/`:

- `code-quality.md` - Standards for reading before writing, keeping it simple, measurement over estimation.

## Installation Options

```bash
# Install everything
./install.sh

# Preview without installing
./install.sh --dry-run

# Install only agents
./install.sh --agents-only

# Install only commands
./install.sh --commands-only

# Install only skills
./install.sh --skills-only

# Install only hooks
./install.sh --hooks-only

# Skip skills
./install.sh --no-skills

# Skip hooks
./install.sh --no-hooks

# Skip statusline
./install.sh --no-statusline

# Verbose output
./install.sh -v

# Custom Claude directory
./install.sh --claude-dir /path/to/.claude
```

## Update

Pull the latest versions without re-cloning:

```bash
./update.sh

# Preview what would be updated
./update.sh --dry-run

# Custom Claude directory
./update.sh --claude-dir /path/to/.claude
```

Agents and commands are always refreshed; skills, hooks, and statusline are updated when installed.

## Uninstall

Remove all installed tools:

```bash
./uninstall.sh

# Preview what would be removed
./uninstall.sh --dry-run

# Skip confirmation
./uninstall.sh --force

# Custom Claude directory
./uninstall.sh --claude-dir /path/to/.claude
```

## Manual Installation

### Agents
```bash
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/
```

### Commands
```bash
mkdir -p ~/.claude/commands
cp commands/*.md ~/.claude/commands/
```

### Skills
```bash
# Linear (includes dependencies)
cd skills/linear && ./install.sh

# verify-changes (just copy the skill file)
mkdir -p ~/.claude/skills/verify-changes
cp skills/verify-changes/SKILL.md ~/.claude/skills/verify-changes/
```

### Statusline
```bash
cp statusline/flying-dutchman-statusline.sh ~/.claude/
chmod +x ~/.claude/flying-dutchman-statusline.sh
# Add to ~/.claude/settings.json:
# "statusline": "~/.claude/flying-dutchman-statusline.sh"
```

### Hooks
```bash
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
# Add to ~/.claude/settings.json under "hooks" - see hooks/README.md
```

### Rules
```bash
mkdir -p ~/.claude/rules
cp rules/*.md ~/.claude/rules/
# Reference in ~/.claude/CLAUDE.md: @~/.claude/rules/code-quality.md
```

## Agent Structure

Each agent follows a consistent structure:

```yaml
---
name: agent-name
author: Andrew Wilkinson (github.com/ADWilkinson)
description: Brief description for when to use this agent
model: sonnet | opus
tools: Read, Edit, MultiEdit, Write, Bash, Grep, Glob, LS, WebFetch
---

You are an expert...

## When Invoked
1. Step 1
2. Step 2
...

## Core Expertise
- Skill 1
- Skill 2

## Code Patterns
```code examples```

## Quality/Security Checklist
- [ ] Item 1
- [ ] Item 2

## Handoff Protocol
- **Related task**: HANDOFF:other-agent
```

## Creating Your Own

Templates are included if you want to fork and create your own tools:

```bash
# Create a new agent
cp templates/agent-template.md agents/your-agent-name.md

# Create a new skill
mkdir -p skills/your-skill/scripts
cp templates/skill-template.md skills/your-skill/SKILL.md

# Create a new command
cp templates/command-template.md commands/your-command.md
```

Follow existing naming conventions (kebab-case) and include clear descriptions for when Claude should invoke your tool.

## Author

Andrew Wilkinson ([@davyjones0x](https://x.com/davyjones0x))

## License

MIT
