---
description: Run Lighthouse audits and iteratively fix issues until target scores are met. Optimizes performance, accessibility, best practices, and SEO.
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, TodoWrite
---

# /lighthouse

Run Lighthouse audits on a web app and iteratively fix issues until target scores are achieved.

## Arguments

Parse user input for:
- `<url>` - URL to audit (default: detect from dev server)
- `--target <n>` - Target score for all categories (default: 95)
- `--categories <list>` - Categories to check: performance,accessibility,best-practices,seo (default: all)
- `--fix` - Automatically apply known fixes (default: true)
- `--max-iterations <n>` - Maximum optimization iterations (default: 5)

## Step 1: Detect Project and Start Server

### Detect project type
```bash
# Check for package.json
if [ -f "package.json" ]; then
    # Check for framework
    grep -l "next\|vite\|react-scripts\|nuxt\|gatsby" package.json
fi
```

### Detect package manager
```bash
if [ -f "bun.lockb" ]; then PM="bun"
elif [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "yarn.lock" ]; then PM="yarn"
else PM="npm"; fi
```

### Build and start server
For accurate results, always test production builds:

**Next.js:**
```bash
$PM run build && $PM start &
# Wait for server, typically port 3000
```

**Vite:**
```bash
$PM run build && $PM run preview &
# Wait for server, typically port 4173 or 5173
```

**Create React App:**
```bash
$PM run build && npx serve -s build &
```

Wait for server to respond before proceeding:
```bash
sleep 5
curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT
```

## Step 2: Run Lighthouse Audit

```bash
npx lighthouse $URL \
  --output=json \
  --output-path=./lighthouse-report.json \
  --only-categories=performance,accessibility,best-practices,seo \
  --chrome-flags="--headless --no-sandbox" 2>&1
```

### Parse Results
```bash
cat lighthouse-report.json | jq '{
  performance: (.categories.performance.score * 100),
  accessibility: (.categories.accessibility.score * 100),
  bestPractices: (.categories["best-practices"].score * 100),
  seo: (.categories.seo.score * 100)
}'
```

### Check failing audits
```bash
cat lighthouse-report.json | jq '.audits | to_entries |
  map(select(.value.scoreDisplayMode == "binary" and .value.score == 0)) |
  map({id: .key, title: .value.title})'
```

### Get details for specific audit
```bash
cat lighthouse-report.json | jq '.audits["<audit-id>"].details.items'
```

## Step 3: Apply Known Fixes

For each failing audit, apply the appropriate fix:

### Accessibility Fixes

**color-contrast** - Text doesn't meet WCAG contrast requirements
- Check audit details for specific failing elements
- Increase contrast to 4.5:1 for small text, 3:1 for large text
- Replace opacity-based colors (e.g., `text-gray-500/60`) with solid colors
- Verify both light and dark theme variants

**aria-dialog-name** - Dialogs missing accessible names
- Add `aria-label` or `aria-labelledby` to dialog elements
- Third-party modals may not be fixable

**label-content-name-mismatch** - Accessible name doesn't match visible text
- Remove redundant `aria-label` when visible text is sufficient
- If both needed, ensure `aria-label` contains the visible text

**aria-allowed-attr** - Invalid ARIA attributes
- Remove `aria-pressed` from `role="tab"` or `role="combobox"` elements
- Check component libraries for incorrect ARIA usage

**button-name / link-name** - Missing accessible names
- Add text content or `aria-label` to interactive elements
- Ensure icon-only buttons have descriptive labels

**target-size** - Touch targets too small
- Increase padding to ensure 24x24px minimum
- Common fix: `py-1` → `py-2` or add `p-2`

### Best Practices Fixes

**errors-in-console** - Browser errors logged
- Fix 404 errors for missing resources
- Make analytics/tracking conditional on production:
  ```tsx
  // Next.js (server component)
  {process.env.VERCEL && <Analytics />}

  // Client-side check
  {typeof window !== 'undefined' &&
   !window.location.hostname.includes('localhost') && <Analytics />}
  ```

**valid-source-maps** - Missing source maps
- Enable in build config:
  ```ts
  // vite.config.ts
  build: { sourcemap: true }

  // next.config.js
  productionBrowserSourceMaps: true
  ```

**third-party-cookies** - Third-party cookies detected
- Often from auth providers or analytics - may require architectural changes
- Document as acceptable if core functionality depends on it

### SEO Fixes

**document-title** - Missing title
- Add `<title>` in head or use framework metadata API

**meta-description** - Missing meta description
- Add `<meta name="description" content="...">`

**viewport** - Missing or invalid viewport
- Ensure `<meta name="viewport" content="width=device-width, initial-scale=1">`

**crawlable-anchors** - Links not crawlable
- Ensure links have valid `href` attributes
- Avoid `javascript:void(0)` or empty hrefs

### Performance Fixes

**font-display** - Fonts blocking render
- Add `font-display: swap` to @font-face rules
- Use framework font optimization (next/font, etc.)

**render-blocking-resources** - CSS/JS blocking render
- Defer non-critical scripts
- Preload critical resources:
  ```html
  <link rel="preload" href="/font.woff2" as="font" type="font/woff2" crossorigin>
  ```

**unused-javascript** - Large unused JS bundles
- Implement code splitting with dynamic imports
- Tree-shake unused dependencies
- Large third-party SDKs may be unavoidable

**largest-contentful-paint** - Slow LCP
- Preload LCP image/element
- Reduce server response time
- Minimize render-blocking resources

**cumulative-layout-shift** - Layout shifts
- Set explicit dimensions on images/embeds
- Reserve space for dynamic content

## Step 4: Iterate Until Target Met

After applying fixes:

1. Rebuild the project
2. Restart the preview server
3. Re-run Lighthouse
4. Check if all categories meet target score
5. If not, identify remaining issues and continue fixing
6. Repeat until target met or max iterations reached

### Iteration Tracking

After each iteration, report progress in this format:

```
Iteration #2 of 5
=================
                    Before → After  (Δ)
Performance:          65   →   78   (+13)
Accessibility:        88   →   95   (+7)
Best Practices:       73   →   85   (+12)
SEO:                  91   →   100  (+9)
                    ─────────────────────
Total:              317   →  358   (+41)

Issues fixed this run:
  ✓ Added aria-label to icon buttons (accessibility)
  ✓ Enabled source maps (best-practices)
  ✓ Added meta description (seo)

Remaining issues (by priority):
  Critical:
    - render-blocking-resources (performance, -15 pts)
  Serious:
    - unused-javascript (performance, -8 pts)
  Moderate:
    - image-size-responsive (performance, -3 pts)

Progress: 358/400 (89.5%) | Target: 380/400 (95%)
Status: CONTINUE (22 points to target)
```

## Step 5: Report Results

### Success Report
```
Lighthouse Optimization Complete

| Category       | Initial | Final | Target |
|----------------|---------|-------|--------|
| Performance    | 65      | 95    | 95     |
| Accessibility  | 88      | 100   | 95     |
| Best Practices | 73      | 96    | 95     |
| SEO            | 91      | 100   | 95     |

Changes Made:
- [List specific fixes applied]

Remaining Issues (if any):
- [Document issues that can't be fixed and why]
```

### When Target Can't Be Met
If scores can't reach target, clearly explain:
- What's blocking improvement
- Whether it's fixable with more effort vs. architectural constraint
- Recommend adjusted target if appropriate

## Common Patterns

```bash
# Quick audit only (no fixes)
/lighthouse --no-fix

# Single category
/lighthouse --categories accessibility

# Lower target
/lighthouse --target 80

# Audit production URL
/lighthouse https://example.com
```

## Cleanup

```bash
# Remove lighthouse reports
rm -f lighthouse-report.json lh-report.json

# Kill preview server
pkill -f "next start\|vite preview" 2>/dev/null
```
