---
name: design-audit
author: Andrew Wilkinson (github.com/ADWilkinson)
description: Audit UI code for accessibility violations and visual consistency issues with scoring
allowed-tools: Read, Glob, Grep, Bash, Task
disable-model-invocation: true
---

# /design-audit

> **Quick Reference**: Detect UI files → Run accessibility checks (WCAG) → Run visual consistency checks → Score issues → Output prioritized report.

Reviews frontend code for accessibility violations and visual inconsistencies. Returns a scored report with prioritized issues.

## Confidence Scoring

Rate each issue found on a 0-100 scale:

| Score | Meaning | Report? |
|-------|---------|---------|
| 0-25 | Might be intentional design choice | Skip |
| 50 | Likely issue, but could be justified | Include with caveat |
| 75-100 | Definitely an issue | Report as finding |

**Only report issues with confidence ≥50.** High-confidence issues (≥75) should be prioritized.

## Arguments

Parse user input for:
- `<path>` - Path to audit (default: detect recently changed files via git)
- `--strict` - Enable strict mode (load ui-constraints rule)
- `--category <name>` - Focus on specific category: accessibility, visual, performance
- `--fix` - Attempt to auto-fix simple issues

## Step 1: Detect Files to Audit

### Recently changed files (default)
```bash
git diff --name-only HEAD~5 -- '*.tsx' '*.jsx' '*.vue' '*.svelte' | head -20
```

### Specific path
```bash
find <path> -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" \) | head -50
```

## Step 2: Run Accessibility Audit

### Critical Issues (WCAG Level A - must fix)

**Missing alt text**
```bash
# Find images without alt
grep -rn '<img' --include="*.tsx" --include="*.jsx" | grep -v 'alt='
```
- Every `<img>` needs `alt` attribute
- Decorative images use `alt=""`
- Informative images need descriptive text

**Buttons/links without accessible names**
```bash
# Icon-only buttons without aria-label
grep -rn '<button' --include="*.tsx" | grep -v 'aria-label'
grep -rn '<IconButton' --include="*.tsx" | grep -v 'aria-label'
```
- Icon buttons need `aria-label`
- Links need visible text or `aria-label`

**Form inputs without labels**
```bash
# Inputs without associated labels
grep -rn '<input' --include="*.tsx" | grep -v -E '(aria-label|id=.*label)'
```
- Use explicit `<label htmlFor="">` or `aria-label`
- Never rely on placeholder alone

### Serious Issues (WCAG Level AA - should fix)

**Removed focus outlines**
```bash
grep -rn 'outline.*none\|outline.*0' --include="*.css" --include="*.scss" --include="*.tsx"
```
- Never remove focus without replacement
- Use `:focus-visible` with custom focus styles

**Missing keyboard handlers**
```bash
# onClick without onKeyDown on non-button elements
grep -rn 'onClick' --include="*.tsx" | grep -E '<div|<span' | grep -v 'onKeyDown'
```
- Clickable divs/spans need `onKeyDown` and `role="button"`
- Better: use actual `<button>` elements

**Color contrast issues**
```bash
# Common low-contrast patterns
grep -rn 'text-gray-400\|text-slate-400\|opacity-50' --include="*.tsx"
```
- Text needs 4.5:1 contrast ratio (3:1 for large text)
- Check with browser DevTools or Lighthouse

### Moderate Issues (WCAG Level AAA - consider)

**Skipped heading levels**
- Check that headings follow h1 → h2 → h3 order
- Don't skip from h1 to h3

**Improper tabIndex**
- `tabIndex > 0` disrupts natural tab order
- Use `tabIndex={0}` or `tabIndex={-1}` only

## Step 3: Run Visual Consistency Audit

### Spacing Inconsistencies

**Mixed spacing units**
```bash
# Look for inconsistent spacing
grep -rn 'margin.*px\|padding.*px' --include="*.tsx" --include="*.css"
grep -rn 'p-[0-9]\|m-[0-9]\|gap-[0-9]' --include="*.tsx"
```
- Use design system spacing scale (Tailwind: 1, 2, 3, 4, 6, 8, 12, 16...)
- Avoid arbitrary values like `p-[13px]`

**Arbitrary z-index**
```bash
grep -rn 'z-\[' --include="*.tsx"
grep -rn 'z-index.*[0-9]' --include="*.css"
```
- Use fixed scale: 10, 20, 30, 40, 50
- Document what each level is for

### Typography Issues

**Missing text-balance on headings**
```bash
grep -rn '<h[1-3]' --include="*.tsx" | grep -v 'text-balance'
```
- Add `text-balance` class to headings for better wrapping

**Inconsistent font sizes**
- Check for arbitrary font sizes outside design system

### Component State Issues

**Missing component states**
- Buttons need: default, hover, active, focus, disabled
- Inputs need: default, focus, error, disabled
- Check for missing `disabled:` variants

**Missing loading states**
- Async actions need loading indicators
- Buttons should show spinner, not just disable

### Animation Issues

**Unrequested animations**
```bash
grep -rn 'animate-\|transition-\|@keyframes' --include="*.tsx" --include="*.css"
```
- No animation unless explicitly requested
- All animations must respect `prefers-reduced-motion`

**Layout-shifting animations**
```bash
grep -rn 'transition.*width\|transition.*height\|animate.*scale' --include="*.tsx"
```
- Only animate `transform` and `opacity` (compositor properties)
- Avoid animating layout properties

## Step 4: Calculate Score

### Scoring Formula

| Category | Weight | Max Points |
|----------|--------|------------|
| Accessibility (Critical) | x3 | 30 |
| Accessibility (Serious) | x2 | 20 |
| Accessibility (Moderate) | x1 | 10 |
| Visual Consistency | x2 | 20 |
| Component States | x1 | 10 |
| Animation/Motion | x1 | 10 |

Start at 100, deduct per issue:
- Critical: -10 points each
- Serious: -5 points each
- Moderate: -2 points each

## Step 5: Output Report

```
Design Audit Results
====================
Score: 72/100

Files audited: 15
  src/components/Button.tsx
  src/components/Card.tsx
  ...

Critical (must fix):
  src/components/IconButton.tsx:24
    Icon button missing aria-label
    Fix: Add aria-label="Close" or similar descriptive text
    Ref: WCAG 2.1 SC 4.1.2

  src/components/Card.tsx:15
    Image missing alt attribute
    Fix: Add alt="Product image" or alt="" if decorative
    Ref: WCAG 2.1 SC 1.1.1

Serious (should fix):
  src/components/Input.tsx:8
    Focus outline removed without replacement
    Fix: Add custom focus-visible styles
    Ref: WCAG 2.1 SC 2.4.7

  src/components/Dropdown.tsx:45
    Clickable div without keyboard handler
    Fix: Add onKeyDown and role="button", or use <button>
    Ref: WCAG 2.1 SC 2.1.1

Moderate (consider):
  src/components/Hero.tsx:3
    h3 follows h1 (skipped h2)
    Fix: Use h2 or restructure heading hierarchy

Visual Consistency:
  src/components/Modal.tsx:12
    Arbitrary z-index (z-[999])
    Fix: Use z-50 from standard scale

  src/components/Card.tsx:8
    Missing hover state on interactive card
    Fix: Add hover:shadow-md or similar feedback

Summary
-------
Critical:    2 issues (-20 pts)
Serious:     2 issues (-10 pts)
Moderate:    1 issue  (-2 pts)
Visual:      2 issues (-6 pts)
             ─────────────────
Total:       7 issues (-38 pts)

Recommendation: Fix critical issues before shipping.
Run with --fix to auto-fix simple issues.
```

## Auto-Fix Capabilities

When `--fix` is passed, attempt to fix:

1. **Missing alt on decorative images** → Add `alt=""`
2. **Missing aria-label on icon buttons** → Add placeholder `aria-label="TODO: add label"`
3. **Removed focus outlines** → Add `:focus-visible` with ring style
4. **Missing text-balance** → Add class to headings

Report what was fixed vs what needs manual attention.

## False Positives (Do NOT Flag)

Skip these common patterns that look like issues but are intentional:

**Accessibility:**
- Images with `role="presentation"` or `aria-hidden="true"` (intentionally decorative)
- Buttons with `aria-label` set via props/variables (dynamic labels)
- Inputs with labels connected via `aria-labelledby` pointing to another element
- Custom focus styles using `ring-*` classes (valid focus replacement)
- `outline-none` paired with `focus-visible:ring-*` (proper focus handling)

**Visual Consistency:**
- Design system utility classes that intentionally break the spacing scale
- Z-index values in third-party component overrides
- Animations with `prefers-reduced-motion` media query handling
- Responsive spacing that intentionally varies by breakpoint

**Framework-Specific:**
- Next.js Image components (alt handled differently)
- Headless UI / Radix components (accessibility built-in)
- Icon libraries with their own accessibility patterns

## Thorough Mode (--thorough)

When `--thorough` is passed, launch parallel validation agents:

```bash
/design-audit --thorough src/components/
```

**Phase 1: Multi-Agent Scan**
Launch 3 specialized scans in parallel using Task tool:

1. **Accessibility Agent** (subagent_type: "frontend-developer"):
   Focus exclusively on WCAG violations. Check every interactive element.

2. **Visual Consistency Agent** (subagent_type: "frontend-developer"):
   Focus on spacing, typography, color, and component state consistency.

3. **Component Coverage Agent** (subagent_type: "frontend-developer"):
   Check for missing states (loading, error, disabled, empty).

**Phase 2: Validate and Dedupe**
- Consolidate findings from all agents
- Remove duplicates
- Validate each issue against false positive list
- Assign confidence scores

**Phase 3: Final Report**
Output consolidated report with validated issues only.

## Common Patterns

```bash
# Quick audit of recent changes
/design-audit

# Audit specific directory
/design-audit src/components/

# Strict mode (loads ui-constraints rule)
/design-audit --strict

# Focus on accessibility only
/design-audit --category accessibility

# Auto-fix simple issues
/design-audit --fix
```
