---
name: generate-precommit-hooks
author: Andrew Wilkinson (github.com/ADWilkinson)
description: Detect project type and set up appropriate pre-commit hooks
disable-model-invocation: true
---

# Generate Pre-commit Hooks

Analyze the current project and generate appropriate pre-commit hooks based on the tech stack.

## Instructions

1. **Detect project type** by checking for:
   - `package.json` (Node/TypeScript/JavaScript)
   - `Cargo.toml` (Rust)
   - `pyproject.toml` or `requirements.txt` (Python)
   - `go.mod` (Go)
   - `foundry.toml` (Solidity/Foundry)
   - `hardhat.config.js/ts` (Solidity/Hardhat)

2. **Check existing setup**:
   - Look for `.husky/` directory
   - Check for `lint-staged` config in package.json
   - Check for `.pre-commit-config.yaml`
   - Check for existing git hooks in `.git/hooks/`

3. **Generate appropriate hooks** based on project:

   **Node/TypeScript projects:**
   - Install husky + lint-staged if not present
   - Add pre-commit: lint-staged (eslint, prettier)
   - Add pre-push: type-check, tests
   - Configure lint-staged in package.json

   **Python projects:**
   - Create `.pre-commit-config.yaml`
   - Add: ruff (format + lint), mypy, pytest
   - Run `pre-commit install`

   **Rust projects:**
   - Create `.cargo/config.toml` with rustfmt settings if needed
   - Add git hook for: cargo fmt --check, cargo clippy, cargo test

   **Go projects:**
   - Add git hook for: gofmt, go vet, go test

   **Solidity/Foundry projects:**
   - Add git hook for: forge fmt --check, forge build, forge test

4. **Install and test**:
   - Run the installation commands
   - Make a test commit to verify hooks work
   - Show the user what was set up

## Example Output

After generating hooks, provide:
- Summary of what was installed
- How to skip hooks if needed (`git commit --no-verify`)
- How to modify the configuration

## Usage

```
/generate-precommit-hooks
```
