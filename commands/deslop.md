# Remove AI Code Slop

Check the diff against main (or specified base branch) and remove AI-generated slop.

## What to Remove

1. **Extra comments** that a human wouldn't add or are inconsistent with the rest of the file
2. **Defensive checks** for impossible cases (e.g., null checks on required params)
3. **Silent try/catch blocks** that swallow errors without justification
4. **Type escapes** like `as any`, `// @ts-ignore`, `# type: ignore`
5. **Console.logs** that weren't intentional debug statements
6. **Style inconsistencies** with the rest of the file
7. **Over-documentation** (excessive JSDoc, comments explaining obvious code)
8. **Backwards-compat shims** for things that weren't there before

## Process

1. Get diff: `git diff main...HEAD` (or specified branch)
2. For each changed file, compare new code against existing file style
3. Remove slop surgically - don't refactor unrelated code
4. Run linter after changes

## Output

Report only a 1-3 sentence summary of what was changed. No verbose explanations.
