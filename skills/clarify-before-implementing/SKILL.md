---
name: clarify-before-implementing
description: Use when user requests implementation work (implement, add, create, build, refactor, fix) AND the request lacks clear acceptance criteria, scope, or constraints. Do NOT use during exploration, explanation, or continuation of ongoing work.
---

# Clarify Before Implementing

Ask minimum clarifying questions to avoid wrong work. Don't start implementing until must-have questions are answered.

## When to Trigger

Request is underspecified if any of these are unclear:
- What should change vs stay the same
- Definition of "done" (acceptance criteria)
- Scope (which files/components are in/out)
- Constraints (compatibility, performance, deps)

If multiple plausible interpretations exist, clarify first.

## Question Format

Ask 1-5 questions. Make them easy to answer:

```
1) Scope?
   a) Minimal change (default)
   b) Refactor while touching the area
   c) Not sure - use default

2) Compatibility?
   a) Current project defaults (default)
   b) Also support older versions: <specify>

Reply: `defaults` or `1a 2b`
```

## Rules

- Offer multiple-choice with clear defaults
- Include fast-path: "reply `defaults` to accept all"
- Bold the recommended option
- Don't ask questions you can answer by reading the codebase
- Don't ask open-ended when yes/no would work

## Before Acting

Until must-have answers arrive:
- Do NOT run commands, edit files, or produce detailed plans
- DO perform low-risk discovery (inspect repo structure, read configs)

If user says "just do it":
- State assumptions as numbered list
- Ask for confirmation
- Proceed only after they confirm
