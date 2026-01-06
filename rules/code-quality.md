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

---

## Prescriptive Rules (MUST follow)

### Bug Fixes Require Tests
Every bug fix MUST include a test that:
1. Reproduces the bug (fails before fix)
2. Passes after the fix
3. Prevents regression

No exceptions unless: UI-only bugs requiring visual inspection, or third-party integration issues that can't be mocked.

### No Silent Exception Swallowing
Every try/catch block MUST either:
- Log the error AND re-raise/rethrow, OR
- Have an explicit comment explaining why it's safe to continue

```typescript
// BAD: Silent failure
try { doThing(); } catch (e) { /* nothing */ }

// GOOD: Log and rethrow
try { doThing(); } catch (e) { logger.error(e); throw e; }

// GOOD: Explicit justification
try { doThing(); } catch (e) {
  // Safe to continue: optional analytics, failure doesn't affect core flow
}
```

### No Defensive Coding for Impossible Cases
Don't handle scenarios that can't happen. Fail fast when assumptions are violated.

```typescript
// BAD: Required dep can't be undefined
if (requiredService) { requiredService.call(); }

// GOOD: Just use it
requiredService.call();
```

Acceptable defensive code: optional dependencies, runtime errors that can legitimately occur, security fail-secure patterns with explicit justification.

### Database Queries Must Be Bounded
Every SELECT query MUST have a LIMIT clause or equivalent constraint.

```typescript
// BAD: Could return millions of rows
db.query("SELECT * FROM events")
supabase.from("events").select("*")

// GOOD: Explicit limit
db.query("SELECT * FROM events LIMIT 100")
supabase.from("events").select("*").limit(100)
```

Exceptions: COUNT(*), queries with WHERE id = X (single row), aggregations with known small cardinality.

### No Client-Side Console Logging
Never add console.log/warn/error to frontend code.
- Security risk: exposes implementation details in DevTools
- Data leakage: user data can end up in logs
- Unprofessional: production apps shouldn't spam console

Use: breakpoints, DevTools network tab, server-side error reporting.
Development-only logging with process.env check is acceptable.

### Centralized Configuration
All environment variables should be accessed through a central config/settings module.

```typescript
// BAD: Scattered across codebase
const apiKey = process.env.API_KEY;

// GOOD: Single source of truth
import { config } from '@/config';
const apiKey = config.apiKey;
```
