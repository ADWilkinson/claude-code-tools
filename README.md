# Claude Code Tools

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub last commit](https://img.shields.io/github/last-commit/ADWilkinson/claude-code-tools)](https://github.com/ADWilkinson/claude-code-tools/commits/main)
[![GitHub stars](https://img.shields.io/github/stars/ADWilkinson/claude-code-tools?style=social)](https://github.com/ADWilkinson/claude-code-tools)

Custom agents, commands, skills, and statusline for [Claude Code](https://github.com/anthropics/claude-code).

## Quick Install

```bash
git clone https://github.com/ADWilkinson/claude-code-tools.git
cd claude-code-tools
./install.sh
```

## What's Included

### Agents (12)

Specialized subagents invoked automatically by Claude Code's Task tool:

| Agent | Description |
|-------|-------------|
| `backend-developer` | Express/Node.js, REST APIs, authentication, webhooks |
| `blockchain-specialist` | Solidity, Wagmi, multi-chain, gas optimization |
| `database-manager` | PostgreSQL, Prisma ORM, query optimization |
| `devops-engineer` | CI/CD, Docker, GitHub Actions, cloud deployment |
| `extension-developer` | Chrome Manifest V3, service workers, messaging |
| `firebase-specialist` | Firestore, Cloud Functions, FCM, security rules |
| `frontend-developer` | React, Next.js, TanStack Query, Tailwind |
| `indexer-developer` | Envio, The Graph, GraphQL, event handlers |
| `mobile-developer` | React Native, Expo, biometrics, push notifications |
| `performance-engineer` | Profiling, caching, load testing, optimization |
| `testing-specialist` | Jest, Playwright, E2E, mocking strategies |
| `zk-specialist` | ZK circuits, Circom/Noir, trusted setup |

All agents use **opus** model for maximum capability.

### Skills (1)

Auto-invoked skills that Claude applies when relevant:

| Skill | Trigger | Description |
|-------|---------|-------------|
| `linear` | "tasks", "issues", "Linear" | Full Linear task management - view, search, create, update issues |

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

### Commands (2)

Slash commands for common workflows:

- `/repo-polish` - Fire-and-forget repository cleanup. Creates a branch, fixes issues, opens a PR.
- `/update-claudes` - Generates CLAUDE.md files throughout your project for AI context.

### Statusline

Custom statusline showing:
- Current directory and git branch
- Activity icons for active tools
- Cumulative cost tracking
- Code diff stats (+/- lines)

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

# Skip statusline
./install.sh --no-statusline

# Verbose output
./install.sh -v

# Custom Claude directory
./install.sh --claude-dir /path/to/.claude
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

### Statusline
```bash
cp statusline/flying-dutchman-statusline.sh ~/.claude/
chmod +x ~/.claude/flying-dutchman-statusline.sh
# Add to ~/.claude/settings.json:
# "statusline": "~/.claude/flying-dutchman-statusline.sh"
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

## Contributing

Want to add your own agents, skills, or commands? Templates are provided:

```bash
# Create a new agent
cp templates/agent-template.md agents/your-agent-name.md

# Create a new skill
mkdir -p skills/your-skill/scripts
cp templates/skill-template.md skills/your-skill/SKILL.md

# Create a new command
cp templates/command-template.md commands/your-command.md
```

**Guidelines:**
- Follow existing naming conventions (kebab-case)
- Include clear descriptions for when Claude should invoke your tool
- Test locally before submitting
- Keep dependencies minimal

PRs welcome. For major changes, open an issue first.

## Author

Andrew Wilkinson ([@davyjones0x](https://x.com/davyjones0x))

## License

MIT
