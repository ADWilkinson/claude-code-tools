---
name: linear
author: Andrew Wilkinson (github.com/ADWilkinson)
description: Manage Linear tasks and issues. Use when the user mentions Linear, tasks, issues, tickets, backlog, sprints, or wants to create/view/update work items.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Linear Task Manager

Simple Linear integration for daily task management.

## Setup Check

Before any Linear operation, verify the API key exists:

```bash
[ -n "$LINEAR_API_KEY" ] && echo "Linear configured" || echo "Set LINEAR_API_KEY in your shell profile"
```

If not configured, tell the user to add to `~/.zshrc`:
```bash
export LINEAR_API_KEY="lin_api_..."
```

Get key from: Linear → Settings → Security & access → Personal API keys

## Operations

### View My Tasks

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts my-tasks
```

### View In Progress

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts in-progress
```

### Create Task (Assigned to Me)

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts create "Task title" --assignee me
```

### Create Backlog Item (Unassigned)

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts create "Task title"
```

### Complete a Task

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts done ISSUE-ID
```

### Start Working on Task

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts start ISSUE-ID
```

### View Specific Issue

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts show ISSUE-ID
```

### Add Comment

```bash
npx tsx ~/.claude/skills/linear/scripts/linear.ts comment ISSUE-ID "Comment text"
```

## State Conventions

| Scenario | State |
|----------|-------|
| Assigned to me | Todo |
| Unassigned | Backlog |
| Started work | In Progress |
| Completed | Done |

## Natural Language Mapping

| User says | Action |
|-----------|--------|
| "show my tasks" / "what's on my plate" | `my-tasks` |
| "what am I working on" | `in-progress` |
| "create task: X" / "add task X" | `create "X" --assignee me` |
| "add to backlog: X" | `create "X"` |
| "done with X" / "complete X" / "finished X" | `done X` |
| "start X" / "working on X" | `start X` |
| "show X" / "details on X" | `show X` |

## Output Format

Always format task output as a clean table:

```
ID        | Title                    | State       | Priority
----------|--------------------------|-------------|----------
ENG-123   | Fix login bug            | In Progress | High
ENG-124   | Update docs              | Todo        | Medium
```

## Error Handling

If LINEAR_API_KEY is missing, respond with setup instructions.
If an issue ID doesn't exist, say so clearly.
If the API fails, show the error and suggest checking the API key.
