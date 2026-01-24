---
name: minimize-ui
author: Andrew Wilkinson (github.com/ADWilkinson)
description: Ruthlessly simplify interfaces through systematic reduction. Use when UI feels cluttered, has competing elements, or needs production-ready polish. Removes before adding. Less is more.
allowed-tools: Read, Edit, Write, Bash, Glob, Grep, Skill, TodoWrite, AskUserQuestion
disable-model-invocation: true
---

# /minimize-ui

> **Quick Reference**: Create branch → Gather context → Audit (remove/combine/hide/simplify) → Execute by impact level → Polish → Create PR.

Systematic interface minimalization through ruthless reduction. Less is more.

## Philosophy

**Every element must earn its place.** Default answer: remove it. Whitespace is a feature, not empty space. Simplicity compounds.

## Design Principles Applied

This command applies proven web design principles:

1. **Proximity Principle** - Inner spacing < outer spacing. Elements in a group should be closer together than to other groups.
2. **Fitts's Law** - Bigger and closer targets are easier to hit. Make buttons large enough.
3. **Emphasis** - One clear focal point per screen. Create hierarchy, not competition.
4. **White Space** - Generous spacing creates premium feel and focuses attention.
5. **Consistency** - Follow a system of rules (spacing, buttons, colors, interactions).
6. **Modularity** - Everything forms rectangles aligned to a grid.
7. **Anchor Objects** - Place key elements in corners or visual center, not floating.
8. **Z-Pattern & F-Pattern** - Respect natural eye scanning paths for content flow.

## When to Use

Invoke `/minimize-ui` when:
- UI feels cluttered or overwhelming
- Too many competing elements on screen
- Preparing for production launch
- After adding features (time to subtract)
- Design lacks clear visual hierarchy

## Flags

```bash
/minimize-ui              # Default: branch + grouped commits + PR
/minimize-ui --dry-run    # Audit only, show findings, no changes
/minimize-ui --no-pr      # Make changes but don't open PR
/minimize-ui [path]       # Target specific path (e.g., src/app/dashboard)
```

## Workflow

This is a systematic, repeatable process executed in phases:

### Phase 0: Branch Setup

```bash
# Capture current branch
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Pull latest
git pull 2>/dev/null || true

# Create minimize branch with timestamp
MINIMIZE_BRANCH="minimize-ui/$(date +%Y%m%d-%H%M%S)"
git checkout -b "$MINIMIZE_BRANCH"

echo "Working on branch: $MINIMIZE_BRANCH"
echo "Will PR back to: $ORIGINAL_BRANCH"
```

All changes will be made on this branch and PR'd back when complete.

### Phase 1: Gather Context (REQUIRED)

Always start by asking the user:

```
Do you have screenshots or specific areas you want me to focus on?

Options:
1. I have screenshots to share
2. Focus on specific path: [path]
3. Full autonomous audit (I'll run the app and capture screenshots)
4. Quick pass (high-impact only, no screenshots)
```

**If screenshots provided**: Use as primary audit source
**If path specified**: Target that area specifically
**If autonomous**: Discover, run app, capture screenshots, audit systematically
**If quick**: Focus only on highest-impact reductions, skip screenshots

### Phase 2: Discovery & Before State

**Check if app is runnable:**
```bash
# Detect package manager from lockfile
if [ -f "bun.lockb" ]; then
    PM="bun"
elif [ -f "pnpm-lock.yaml" ]; then
    PM="pnpm"
elif [ -f "yarn.lock" ]; then
    PM="yarn"
else
    PM="npm"
fi

# Look for dev server capability
DEV_SCRIPT=$(cat package.json 2>/dev/null | grep -o '"dev": "[^"]*"' | cut -d'"' -f4)
[ -n "$DEV_SCRIPT" ] && echo "Found dev script: $DEV_SCRIPT (using $PM)"
```

**If runnable and user chose option 3 (Full autonomous audit):**

1. **Create screenshot directory:**
   ```bash
   mkdir -p .minimize-ui/before .minimize-ui/after
   ```

2. **Start dev server in background:**
   ```bash
   $PM run dev > .minimize-ui/dev.log 2>&1 &
   DEV_PID=$!
   echo "Started dev server (PID: $DEV_PID)"

   # Wait for server to be ready (check for localhost in logs)
   timeout=30
   while [ $timeout -gt 0 ]; do
     if grep -q "localhost:" .minimize-ui/dev.log 2>/dev/null; then
       PORT=$(grep -o "localhost:[0-9]*" .minimize-ui/dev.log | head -1 | cut -d':' -f2)
       echo "Server ready on port $PORT"
       break
     fi
     sleep 1
     timeout=$((timeout-1))
   done
   ```

3. **Capture before screenshots using webapp-testing skill:**
   - Identify key routes from routing files
   - Capture: Homepage, main screens in user journey
   - Save to `.minimize-ui/before/`
   - Take note of visual complexity (count of elements, colors used, etc.)

4. **Stop dev server:**
   ```bash
   kill $DEV_PID 2>/dev/null || true
   ```

**If not runnable or user declined:**
- Work from code inspection
- Use provided screenshots if available

**Identify all screens/components:**
- Use Glob to find UI files: `**/*.tsx`, `**/*.jsx`, `**/page.tsx`
- Map out user-facing screens
- Identify critical user journey (signup → main action → value)

### Phase 3: Reduction Audit

**Create systematic checklist** using TodoWrite:

For each screen/component, audit against these questions in order:

1. **REMOVE**: What can be deleted entirely?
   - Duplicate CTAs
   - Decorative elements with no function
   - Features shown before they're needed
   - Competing focal points
   - Verbose copy (halve it, then halve again)
   - Elements interrupting natural F-pattern or Z-pattern flow

2. **COMBINE**: What can be consolidated?
   - Similar actions merged into one
   - Multiple CTAs combined
   - Redundant UI elements
   - Buttons and interactive elements (apply Fitts's Law: bigger = easier)

3. **HIDE**: What can use progressive disclosure?
   - Advanced features → behind "More"
   - Secondary actions → hidden until hover/click
   - Complexity → revealed progressively

4. **SIMPLIFY**: What can be text instead of UI?
   - Icons → clear words
   - Visual metaphors → plain language
   - Complex widgets → simple inputs

5. **SPACING**: Does spacing create proper hierarchy? (Proximity Principle)
   - Inner spacing < outer spacing (objects in a group closer than to other groups)
   - Consistent spacing system (4px, 8px, 16px, 24px, 32px)
   - False connections (unrelated elements too close together)
   - Proper alignment to grid (everything forms rectangles)

6. **EMPHASIS**: Is visual hierarchy clear?
   - One primary focal point per screen (not 2-3 competing)
   - Secondary elements visually subordinate
   - Important actions fall on natural scanning path (Z or F pattern)
   - Anchor objects placed in corners or visual center (not floating)

**Document findings** in prioritized list:

```
HIGH IMPACT (Critical path / Maximum noise reduction):
- [ ] Homepage: Remove 2 of 3 competing "Sign Up" CTAs
- [ ] Dashboard: Hide 8 of 12 sidebar items behind "More"
- [ ] Hero: Remove decorative gradient background

MEDIUM IMPACT (Secondary paths / Moderate improvement):
- [ ] Forms: Combine 3 submit buttons into 1
- [ ] Cards: Remove borders, use whitespace instead
- [ ] Navigation: Replace icons with text labels

LOW IMPACT (Nice-to-have polish):
- [ ] Footer: Reduce link count by 50%
- [ ] Typography: Consolidate to 2 sizes from 5
```

### Phase 4: Prioritize & Plan

**Order findings by:**
1. Critical user journey impact (signup → activation → value)
2. Visual noise reduction (biggest declutter wins)
3. Cognitive load reduction (fewer decisions = better UX)

**Create execution plan** using TodoWrite with specific todos:
```
- [ ] Remove duplicate CTAs from homepage hero
- [ ] Consolidate dashboard sidebar navigation
- [ ] Simplify form submit actions
...
```

### Phase 5: Execute in Groups

Execute changes grouped by impact level. This keeps commits focused but not overly granular.

**For HIGH IMPACT changes:**
1. **Read** all files that will be changed in this group
2. **Make all HIGH IMPACT changes** (remove duplicates, simplify colors, consolidate actions)
3. **Mark todos complete** as you finish each
4. **Commit as a group:**
   ```bash
   git add -A
   git commit -m "refactor(ui): remove competing elements and visual noise (HIGH IMPACT)

   - Removed 2 duplicate signup CTAs from hero
   - Consolidated sidebar navigation (12 → 4 items + More)
   - Simplified color palette (6 → 2 colors)"
   ```

**For MEDIUM IMPACT changes:**
1. **Read** and make all MEDIUM IMPACT changes
2. **Mark todos complete**
3. **Commit as a group:**
   ```bash
   git commit -m "refactor(ui): consolidate actions and improve clarity (MEDIUM IMPACT)

   - Combined 3 submit buttons into 1 primary + text link
   - Replaced icon buttons with text labels
   - Removed decorative borders, using whitespace"
   ```

**For LOW IMPACT / Polish changes:**
1. Make all polish changes (spacing, typography, final cleanup)
2. **Commit as a group:**
   ```bash
   git commit -m "refactor(ui): polish spacing and typography

   - Aligned to 8px grid
   - Reduced typography scale (5 → 3 sizes)
   - Added consistent padding/margins"
   ```

**Benefits of grouped commits:**
- Easier to review (3-4 commits vs 15-20)
- Each commit represents a phase of work
- Still reversible at the group level
- Clear progression in git history

### Phase 6: Polish Pass (AFTER Reduction)

Only after removal/combination/hiding, apply polish:

1. **Spacing & Proximity**
   - Align all elements to 8px grid (4px, 8px, 16px, 24px, 32px)
   - **Inner spacing < outer spacing** (critical: groups objects correctly)
   - Consistent padding/margins system
   - Fix false connections (unrelated elements too close)
   - Verify all modules form clean rectangles (Modularity)

2. **Visual Hierarchy & Emphasis**
   - One clear focal point per screen (Anchor Objects in corners/center)
   - Size/color creates hierarchy (not multiple competing elements)
   - Important actions on natural scanning path (Z or F pattern)
   - Remove floating elements (anchor them properly)

3. **Interactive Elements** (Fitts's Law)
   - Buttons large enough to click easily
   - Increase clickable target areas
   - Group related actions together
   - Make primary CTA most prominent

4. **Color reduction**
   - Simplify to 1-2 primary colors
   - Remove decorative color usage
   - Use color for emphasis only
   - Embrace gray scale for neutrals

5. **Typography scale**
   - Reduce to 2-3 sizes maximum
   - Consistent line height (~1.5)
   - Clear hierarchy through size, not color

6. **Consistency Check**
   - Same button styles everywhere (radius, padding, colors)
   - Same border treatments
   - Same spacing patterns
   - Same interaction behaviors

7. **Final cleanup**
   - Remove any remaining decorative borders (whitespace > lines)
   - Eliminate orphans and awkward line breaks
   - Verify one focal point per screen
   - Check natural scanning flow (Z or F pattern)

### Phase 7: After State, PR & Cleanup

**If we captured before screenshots, capture after state:**

1. **Run dev server again:**
   ```bash
   $PM run dev > .minimize-ui/dev.log 2>&1 &
   DEV_PID=$!
   # Wait for ready...
   ```

2. **Capture after screenshots** of same routes in `.minimize-ui/after/`

3. **Generate comparison HTML:**
   ```bash
   cat > .minimize-ui/comparison.html <<'EOF'
   <!DOCTYPE html>
   <html>
   <head>
     <title>UI Minimalization - Before/After</title>
     <style>
       body { font-family: system-ui; max-width: 1400px; margin: 0 auto; padding: 20px; }
       .comparison { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
       .screen { border: 1px solid #ddd; padding: 10px; }
       .screen h3 { margin-top: 0; }
       .screen img { width: 100%; border: 1px solid #eee; }
       .metrics { background: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 8px; }
     </style>
   </head>
   <body>
     <h1>UI Minimalization Results</h1>
     <div class="metrics">
       <h2>Metrics</h2>
       <ul>
         <li>UI elements: 47 → 23 (51% reduction)</li>
         <li>Color palette: 6 → 2 colors</li>
         <li>Typography scale: 5 → 3 sizes</li>
       </ul>
     </div>
     <div class="comparison">
       <div class="screen">
         <h3>Before</h3>
         <img src="before/home.png">
       </div>
       <div class="screen">
         <h3>After</h3>
         <img src="after/home.png">
       </div>
     </div>
   </body>
   </html>
   EOF
   ```

4. **Stop dev server:**
   ```bash
   kill $DEV_PID 2>/dev/null || true
   ```

**Create PR:**

```bash
# Push branch
git push -u origin "$MINIMIZE_BRANCH"

# Create PR with comparison
gh pr create \
  --base "$ORIGINAL_BRANCH" \
  --head "$MINIMIZE_BRANCH" \
  --title "UI Minimalization - Remove before polish" \
  --body "$(cat <<'EOF'
## Summary

Systematic UI minimalization applying the principle: **remove before polish**.

### Changes Made
1. Removed duplicate CTAs (3 → 1)
2. Consolidated sidebar navigation (12 items → 4 + "More")
3. Simplified form actions (3 buttons → 1 + text link)
4. Reduced color palette (6 → 2 colors)
5. Consolidated typography scale (5 → 3 sizes)

### Metrics
- **UI elements**: 47 → 23 (51% reduction)
- **Color palette**: 6 → 2 colors
- **Typography scale**: 5 → 3 sizes
- **CTA buttons per screen**: 3.2 avg → 1.1 avg

### Key Decisions
- Removed decorative gradient (added visual noise without purpose)
- Chose text labels over icons for clarity
- Applied progressive disclosure for advanced features
- Whitespace over borders for visual separation

### Visual Comparison
[View side-by-side comparison](.minimize-ui/comparison.html)

### Test Plan
- [ ] Verify all user journeys still functional
- [ ] Check mobile responsiveness
- [ ] Validate no regressions in accessibility
- [ ] Review visual hierarchy on each screen
EOF
)"

echo "PR created: $(gh pr view --json url -q .url)"
```

**Cleanup:**

```bash
# Optionally remove screenshot directory after PR created
# (User can keep it for review if they want)
echo "Screenshot comparison saved in .minimize-ui/"
echo "Run 'rm -rf .minimize-ui' to clean up after reviewing"
```

## Core Principles (Non-Negotiable)

1. **Remove before polish** - Cut first, beautify what remains
2. **Question everything** - Every element must justify existence
3. **Progressive disclosure** - Hide complexity until needed
4. **Trust whitespace** - Empty space guides the eye
5. **Commit incrementally** - One atomic reduction per commit
6. **Preserve functionality** - Simplify UI, not capabilities
7. **Mobile-first thinking** - Constraints breed clarity

## Anti-Patterns to Hunt

When auditing, actively search for and eliminate:

- **Duplicate CTAs** - "Sign Up" appearing 3+ times
- **Decorative borders** - Use whitespace instead of lines (Proximity Principle)
- **Unnecessary icons** - Text is often clearer
- **Color without purpose** - Gray is underrated (stick to 1-2 colors)
- **Premature feature visibility** - Hide until relevant
- **Competing focal points** - One hero per screen (Emphasis)
- **Verbose copy** - If you can halve it, do
- **Feature flags visible** - Don't show options until needed
- **Inconsistent spacing** - Inner spacing > outer spacing creates false connections
- **Small clickable targets** - Violates Fitts's Law (make buttons easier to hit)
- **Floating elements** - Not anchored to corners or visual center (Anchor Objects)
- **Flow interruption** - Elements that break natural Z or F pattern scanning
- **Inconsistent grid alignment** - Elements not forming clean rectangles (Modularity)
- **Style inconsistency** - Different button radii, borders, or treatments on same page

## Constraints

**MUST preserve:**
- All functionality (simplify UI, not capabilities)
- User's ability to complete tasks
- Accessibility standards

**MUST NOT add:**
- New features (this is reduction only)
- More complexity
- Anything not explicitly requested

**MUST ship:**
- Incrementally (commit after each change)
- With tests passing (if tests exist)
- Mobile-responsive (check small screens)

## Output Format

Throughout execution, maintain clear communication:

1. **Start**: Show the audit findings organized by impact
2. **During**: Mark todos as complete, one at a time
3. **End**: Provide summary with metrics and key decisions

## Success Criteria

A successful minimalization session results in:

✓ Fewer UI elements overall
✓ Clearer visual hierarchy
✓ Reduced cognitive load
✓ One focal point per screen
✓ Simplified color palette
✓ Consistent spacing system
✓ Purposeful whitespace
✓ All functionality preserved
✓ Incremental, reviewable commits
