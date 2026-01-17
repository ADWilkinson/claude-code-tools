# UI Constraints (Strict Mode)

Load this rule for design-sensitive frontend work. These are opinionated constraints that enforce consistency and prevent common UI anti-patterns.

## Absolute Rules (NEVER violate)

### Animation
- **NEVER** add animation unless explicitly requested by the user
- **NEVER** animate layout properties (width, height, top, left, margin, padding)
- **ONLY** animate compositor properties: `transform`, `opacity`
- **ALWAYS** respect `prefers-reduced-motion` media query
- **NEVER** use `transition: all` - explicitly list properties

### Component Systems
- **NEVER** mix component primitive systems in the same project
- Pick ONE: Radix UI, Headless UI, React Aria, Base UI, or native
- Mixing causes inconsistent behavior, focus management issues, and bundle bloat

### Z-Index
- **NEVER** use arbitrary z-index values (`z-[999]`, `z-index: 9999`)
- **USE** fixed scale only: 10, 20, 30, 40, 50
- Document what each level is for in a comment or design tokens

### Inputs
- **NEVER** block paste functionality in any input field
- **NEVER** prevent specific keystrokes (except for format enforcement)
- **ALWAYS** allow browser autofill to function

### Typography
- **ALWAYS** apply `text-balance` to headings (h1, h2, h3)
- **ALWAYS** use relative units for font-size in components
- **NEVER** use font-size below 16px for body text on mobile

## Required Patterns

### Destructive Actions
```tsx
// WRONG: Direct destructive action
<button onClick={handleDelete}>Delete</button>

// RIGHT: Confirmation required
<AlertDialog>
  <AlertDialogTrigger>Delete</AlertDialogTrigger>
  <AlertDialogContent>
    <AlertDialogTitle>Delete item?</AlertDialogTitle>
    <AlertDialogDescription>This cannot be undone.</AlertDialogDescription>
    <AlertDialogCancel>Cancel</AlertDialogCancel>
    <AlertDialogAction onClick={handleDelete}>Delete</AlertDialogAction>
  </AlertDialogContent>
</AlertDialog>
```

### Empty States
- **MUST** have exactly one clear call-to-action
- **MUST** explain what the user can do to populate the state
- **NEVER** show blank screens or just "No data"

```tsx
// WRONG
{items.length === 0 && <p>No items</p>}

// RIGHT
{items.length === 0 && (
  <EmptyState
    title="No items yet"
    description="Create your first item to get started"
    action={<Button onClick={onCreate}>Create Item</Button>}
  />
)}
```

### Form Errors
- **MUST** appear adjacent to the field, not just in a toast
- **MUST** be announced to screen readers
- **MUST** focus the first error field on submit

```tsx
// WRONG: Error only in toast
toast.error("Invalid email")

// RIGHT: Error next to field
<div>
  <Input aria-invalid={!!error} aria-describedby="email-error" />
  {error && <p id="email-error" role="alert">{error}</p>}
</div>
```

### Loading States
- **MUST** preserve button dimensions during loading
- **MUST** show feedback within 200ms of action
- **MUST** have 300-500ms minimum spinner duration (no flicker)

```tsx
// WRONG: Button shrinks during loading
<button>{loading ? <Spinner /> : "Submit"}</button>

// RIGHT: Dimensions preserved
<button className="min-w-[100px]">
  {loading ? <Spinner /> : "Submit"}
</button>
```

## Forbidden Patterns

### Visual
- No blur animations over 8px radius (performance)
- No more than one accent color per view
- No shadows larger than `shadow-xl` without justification
- No gradients on text (accessibility issues)

### Interactive
- No clickable elements smaller than 24x24px desktop, 44x44px mobile
- No hover-only interactions (must work on touch)
- No scroll hijacking or smooth scroll override
- No auto-playing media without user consent

### Layout
- No fixed positioning for content (only for overlays/modals)
- No negative margins for layout (use gap, padding)
- No `!important` except for overriding third-party styles

## Spacing Scale

Use only these values for consistency:

| Token | Value | Use case |
|-------|-------|----------|
| 0 | 0 | Reset |
| 1 | 4px | Tight inline spacing |
| 2 | 8px | Default inline spacing |
| 3 | 12px | Related elements |
| 4 | 16px | Component padding |
| 6 | 24px | Section spacing |
| 8 | 32px | Large gaps |
| 12 | 48px | Section margins |
| 16 | 64px | Page sections |

## Color Usage

### Accent Colors
- ONE accent color per view (buttons, links, highlights)
- Use semantic colors for states: success (green), error (red), warning (amber)
- Never use pure black (#000) or pure white (#fff) for text/backgrounds

### Contrast Requirements
- Body text: 4.5:1 minimum
- Large text (18px+ or 14px bold): 3:1 minimum
- UI components: 3:1 minimum
- Disabled states: exempt but should still be readable

## Enforcement

When reviewing code with this rule loaded:

1. Flag any violations with severity level
2. Provide specific fix with code example
3. Reference the rule being violated
4. Suggest alternatives that comply

```
VIOLATION: Animation on non-compositor property
File: src/Modal.tsx:45
Code: transition-all duration-300
Fix: transition-opacity duration-300 (animate only opacity)
Rule: Only animate transform and opacity
```
