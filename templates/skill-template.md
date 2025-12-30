---
name: your-skill-name
author: Your Name (github.com/yourusername)
description: Describe when this skill should auto-invoke. Include trigger words like "tasks", "issues", specific product names, or action phrases users might say.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Skill Name

Brief description of what this skill does.

## Setup Check

Before any operation, verify required configuration exists:

```bash
[ -n "$YOUR_API_KEY" ] && echo "Configured" || echo "Set YOUR_API_KEY in your shell profile"
```

## Operations

### Operation 1
```bash
npx tsx ~/.claude/skills/your-skill/scripts/your-script.ts operation-1
```

### Operation 2
```bash
npx tsx ~/.claude/skills/your-skill/scripts/your-script.ts operation-2
```

## Usage Examples

| User Says | Action |
|-----------|--------|
| "show my items" | Lists user's items |
| "create item: description" | Creates new item |
| "mark ITEM-123 done" | Updates item status |

## Error Handling

If operations fail, check:
1. API key is set correctly
2. Network connectivity
3. Permissions/access rights
