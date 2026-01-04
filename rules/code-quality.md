# Code Quality Standards

## Before Writing Code
1. **Read first** - Always read existing code before modifying
2. **Understand patterns** - Match existing conventions in the codebase
3. **Check for similar implementations** - Don't reinvent what exists

## While Writing Code
1. **Keep it simple** - Minimum complexity for the task at hand
2. **No over-engineering** - Don't add features, abstractions, or "improvements" not requested
3. **No speculative code** - Don't handle edge cases that can't happen
4. **Delete unused code** - No commented-out code, no backwards-compat shims

## After Writing Code
1. **Verify it works** - Run tests, build, or validate as appropriate
2. **Clean up** - Remove debug statements, console.logs unless intentional

## Measurement Over Estimation
1. **Never guess numbers** - Benchmark instead of estimating performance/size/timing
2. **Say "needs measurement"** - Rather than inventing statistics
3. **Validate small first** - Run sub-minute version before scaling up
