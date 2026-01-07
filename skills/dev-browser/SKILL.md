---
name: dev-browser
author: Andrew Wilkinson (github.com/ADWilkinson)
description: Browser automation for Claude Code. Test UI changes, verify user flows, and catch visual regressions during development. Integrates with verify-changes workflow. Use when testing web apps, debugging UI issues, or validating frontend work.
---

# Dev Browser

Browser automation skill that lets Claude test and verify your web applications during development.

## When to Use

This skill auto-triggers when you:
- Ask to "test the UI" or "verify the page"
- Want to "check if the form works"
- Need to "screenshot the dashboard"
- Request "visual verification" of changes
- Say "open localhost" or "navigate to the app"

## Core Capabilities

### 1. Visual Verification
Take screenshots before/after changes to verify UI modifications:

```
Before implementing: screenshot the current state
After implementing: screenshot and compare
```

### 2. User Flow Testing
Test complete user journeys without leaving Claude Code:

```
1. Navigate to login page
2. Fill credentials
3. Submit form
4. Verify redirect to dashboard
5. Check expected elements are visible
```

### 3. Form Validation Testing
Verify form behavior and error states:

```
- Submit empty form → check error messages
- Submit invalid email → check validation
- Submit valid data → check success state
```

### 4. Responsive Testing
Test across viewport sizes:

```
- Desktop (1920x1080)
- Tablet (768x1024)
- Mobile (375x667)
```

## Integration with verify-changes

When used with the `verify-changes` skill, dev-browser adds UI verification to the standard test suite:

1. **Code verification** (typecheck, lint, test, build)
2. **Visual verification** (screenshot, interaction test)
3. **Flow verification** (critical user paths)

## Execution Patterns

### Quick Check
Single page verification:
```
Open localhost:3000/dashboard and verify the chart renders
```

### Flow Test
Multi-step user journey:
```
Test the checkout flow:
1. Add item to cart
2. Go to checkout
3. Fill shipping info
4. Verify order summary
```

### Visual Regression
Before/after comparison:
```
Screenshot /settings before and after my CSS changes
```

### Error State Testing
Verify error handling:
```
Test what happens when the API returns 500 on /api/users
```

## Best Practices

### DO
- Test on localhost during development
- Verify critical paths after changes
- Screenshot error states for debugging
- Test responsive breakpoints

### DON'T
- Use for production testing (use proper E2E)
- Test authenticated external services
- Rely on this for CI/CD testing
- Test performance-sensitive operations

## Common Workflows

### After Implementing a Feature
```
1. Start dev server if not running
2. Navigate to the feature
3. Test happy path
4. Test error states
5. Screenshot key states
```

### Debugging UI Issues
```
1. Navigate to problem area
2. Inspect DOM structure
3. Check console for errors
4. Test interactions
5. Verify fix
```

### Pre-PR Verification
```
1. Run verify-changes (code)
2. Open app in browser
3. Test affected features
4. Screenshot before/after
5. Confirm ready for review
```

## Example Prompts

| Prompt | Action |
|--------|--------|
| "test the login" | Navigate → fill form → submit → verify |
| "check the dashboard loads" | Navigate → wait → verify elements |
| "screenshot the modal" | Open modal → capture screenshot |
| "verify form validation" | Submit invalid → check errors |
| "test mobile layout" | Resize viewport → screenshot |

## Error Handling

If browser automation fails:
1. Check dev server is running
2. Verify the URL is correct
3. Wait for page load completion
4. Check for JavaScript errors in console

## Notes

- Works best with localhost development servers
- Supports Chrome, Chromium-based browsers
- Can use existing browser sessions via Chrome extension
- Screenshots are saved to working directory by default
