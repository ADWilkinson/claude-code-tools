---
name: verify-changes
author: Andrew Wilkinson (github.com/ADWilkinson)
description: Verifies that changes work correctly by running appropriate tests, builds, and checks. Use after implementing features or fixing bugs to ensure everything works. Provides the verification feedback loop that dramatically improves code quality.
---

# Verify Changes

After making code changes, this skill runs comprehensive verification to catch issues before commit.

## When to Use

- After implementing a feature
- After fixing a bug
- Before creating a PR
- When unsure if changes broke something

## Verification Strategy

1. **Detect project type and available verification commands**:
   - Check package.json scripts (test, lint, typecheck, build)
   - Check for pytest, cargo test, go test, forge test
   - Check for CI workflow files to understand what CI runs

2. **Run verification in order of speed**:
   - **Type checking** (fastest feedback)
   - **Linting** (catches style + some bugs)
   - **Unit tests** (catches logic errors)
   - **Build** (catches compilation errors)
   - **E2E tests** (if quick, or if specifically requested)

3. **For web projects, optionally**:
   - Start dev server
   - Test the UI with Playwright or manually
   - Verify the UX feels right

## Execution by Project Type

### TypeScript/Node
```bash
pnpm run typecheck 2>&1 | head -50
pnpm run lint 2>&1 | head -50
pnpm run test 2>&1 | head -100
pnpm run build 2>&1 | head -50
```

### Python
```bash
ruff check . 2>&1 | head -50
mypy . 2>&1 | head -50
pytest -v 2>&1 | head -100
```

### Rust
```bash
cargo check 2>&1 | head -50
cargo clippy 2>&1 | head -50
cargo test 2>&1 | head -100
```

### Solidity/Foundry
```bash
forge build 2>&1 | head -50
forge test 2>&1 | head -100
```

### Go
```bash
go vet ./... 2>&1 | head -50
go test ./... 2>&1 | head -100
```

## Output

Report:
- What passed
- What failed (with specific errors)
- Suggested fixes for any failures

If everything passes, confirm the changes are ready for commit.

