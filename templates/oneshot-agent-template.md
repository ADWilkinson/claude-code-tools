---
name: oneshot-agent
author: Andrew Wilkinson (github.com/galleonlabs)
description: Template for unattended one-shot coding agents that gather context, run an LLM, verify output, and produce artifacts (PRs, notifications). Use this pattern when you need scheduled or triggered automation that runs without human interaction.
---

# One-Shot Agent Pattern

Unattended coding agent that runs a single task to completion: gather context, run LLM, verify, output. No human in the loop.

## When to Use

- Scheduled maintenance (cron-driven fixes, upgrades, syncs)
- Triggered automation (webhook, Discord command, CI event)
- Batch operations (process N issues, migrate files, update deps)

**Use interactive agents instead** when the task requires judgment calls, user confirmation, or exploratory work where the goal isn't fully defined upfront.

## 5-Phase Pattern

```
1. Context Gathering (deterministic)
   |
2. LLM Loop (prompt + tools)
   |
3. Verification (lint/typecheck/test)
   |
4. Retry? ──yes──> back to 2 (with error context)
   |  no
5. Output (PR/notification/artifact)
```

## Config

```typescript
interface OneshotAgentConfig {
  // LLM settings
  engine: "claude" | "codex";
  model: string;                   // e.g. "opus", "o3-pro"
  timeoutMinutes: number;          // kill switch

  // Retry settings
  maxRetries: number;              // 0 = no retry, 2-3 typical
  retryDelayMs?: number;           // backoff between attempts

  // Verification
  verifyCommand: string;           // e.g. "bun run lint && bun run typecheck && bun run test"

  // Notifications
  notifications: {
    enabled: boolean;
    webhookUrl: string;
    notifyOn: ("success" | "failure" | "pr_created")[];
  };
}
```

## Phase 1: Context Gathering

Deterministic. No LLM calls. Collect everything the agent needs before invoking the model.

```typescript
interface GatheredContext {
  issue?: { number: number; title: string; body: string };
  relevantFiles: string[];
  recentLogs?: string;
  config: Record<string, string>;
}

async function gatherContext(config: OneshotAgentConfig): Promise<GatheredContext> {
  // Fetch the work item (issue, webhook payload, queue entry)
  const issue = pickHighestPriority(
    listIssues(owner, repo, { labels: ["backlog"], state: "open" })
  );

  // Grep/glob for relevant code paths
  const relevantFiles = findRelatedFiles(issue.title, issue.body);

  // Pull operational context (logs, metrics, error states)
  const recentLogs = fetchFirebaseLogs("last-24h");

  return { issue, relevantFiles, recentLogs, config: {} };
}
```

Keep context gathering fast and focused. Over-fetching bloats the prompt and wastes tokens.

## Phase 2: Prompt Template + LLM Execution

Inject gathered context into a template, then run the LLM as a subprocess.

### Prompt Template

```
prompts/your-agent.txt
```

```text
You are an automated {{agent_name}} for the {{repo}} repository.

## Task
{{issue_title}} (#{{issue_number}})

{{issue_body}}

## Relevant Code
{{relevant_files}}

## Constraints
- Do not modify: {{do_not_touch}}
- Branch from main, commit with conventional prefixes
- Open a PR when done using `gh pr create`

## Verification
After making changes, run: {{verify_command}}
Fix any failures before opening the PR.
```

### Template Loader

```typescript
function loadPrompt(name: string, vars: Record<string, string>): string {
  const template = readFileSync(`prompts/${name}.txt`, "utf-8");
  let result = template;
  for (const [key, value] of Object.entries(vars)) {
    result = result.replaceAll(`{{${key}}}`, value);
  }
  return result;
}
```

### LLM Runner

```typescript
async function runLLM(
  prompt: string,
  config: OneshotAgentConfig,
  options?: { cwd?: string },
): Promise<LLMResult> {
  const timeoutMs = config.timeoutMinutes * 60_000;
  const startTime = Date.now();

  // Write prompt to temp file, pipe to stdin
  const tempFile = join(tmpdir(), `prompt-${randomUUID()}.txt`);
  writeFileSync(tempFile, prompt);

  try {
    const proc = Bun.spawn(
      ["claude", "--dangerously-skip-permissions", "-p", "--model", config.model],
      { stdin: Bun.file(tempFile), stdout: "pipe", stderr: "pipe", cwd: options?.cwd },
    );

    const timeout = setTimeout(() => proc.kill(), timeoutMs);
    const output = await new Response(proc.stdout).text();
    const exitCode = await proc.exited;
    clearTimeout(timeout);

    return {
      output,
      exitCode,
      durationMs: Date.now() - startTime,
      prUrls: [...new Set(output.match(/https:\/\/github\.com\/[^\s]+\/pull\/\d+/g) ?? [])],
    };
  } finally {
    try { unlinkSync(tempFile); } catch {}
  }
}
```

## Phase 3: Verification

Deterministic check after LLM completes. Run the same gate you'd run locally.

```typescript
function verify(verifyCommand: string, cwd: string): { pass: boolean; output: string } {
  const result = Bun.spawnSync(["bash", "-c", verifyCommand], { cwd });
  return {
    pass: result.exitCode === 0,
    output: result.stdout.toString() + result.stderr.toString(),
  };
}
```

## Phase 4: Retry Loop

Feed verification errors back to the LLM for another attempt.

```typescript
async function runWithRetries(
  basePrompt: string,
  config: OneshotAgentConfig,
  cwd: string,
): Promise<LLMResult> {
  let lastResult = await runLLM(basePrompt, config, { cwd });

  for (let attempt = 1; attempt <= config.maxRetries; attempt++) {
    if (lastResult.exitCode !== 0) break; // LLM itself failed, don't retry

    const check = verify(config.verifyCommand, cwd);
    if (check.pass) return lastResult;

    const retryPrompt = `${basePrompt}\n\n## Previous Attempt Failed\n\nVerification output:\n\`\`\`\n${check.output}\n\`\`\`\n\nFix the issues and try again.`;

    if (config.retryDelayMs) await Bun.sleep(config.retryDelayMs);
    lastResult = await runLLM(retryPrompt, config, { cwd });
  }

  return lastResult;
}
```

## Phase 5: Output

Collect artifacts and notify.

```typescript
async function handleOutput(
  result: LLMResult,
  config: OneshotAgentConfig,
  context: GatheredContext,
): Promise<void> {
  const success = result.exitCode === 0;
  const duration = Math.round(result.durationMs / 1000);

  if (result.prUrls.length > 0 && config.notifications.notifyOn.includes("pr_created")) {
    await notify(config, `PR created: ${result.prUrls[0]}`);
  }

  if (success && config.notifications.notifyOn.includes("success")) {
    await notify(config, `Completed in ${duration}s`);
  }

  if (!success && config.notifications.notifyOn.includes("failure")) {
    await notify(config, `Failed after ${duration}s`);
  }
}
```

## Putting It Together

```typescript
export async function runAgent(config: OneshotAgentConfig): Promise<void> {
  // 1. Context
  const context = await gatherContext(config);
  if (!context.issue) return; // nothing to do

  // 2 + 3 + 4. LLM + Verify + Retry
  const prompt = loadPrompt("your-agent", {
    issue_title: context.issue.title,
    issue_number: String(context.issue.number),
    issue_body: context.issue.body,
    relevant_files: context.relevantFiles.join("\n"),
    verify_command: config.verifyCommand,
  });

  const result = await runWithRetries(prompt, config, "/path/to/repo");

  // 5. Output
  await handleOutput(result, config, context);
}
```

## Scheduling

Run via cron, supercronic (Docker), or trigger from a webhook/bot command.

```crontab
# Every 3 hours
0 */3 * * * cd /app && bun run run:your-agent >> /var/log/agent.log 2>&1
```

## Checklist

- [ ] Context gathering covers all inputs the LLM needs (no lazy "figure it out" prompts)
- [ ] Prompt template has clear constraints and a defined exit condition (PR, commit, file)
- [ ] Verification runs the same gate as CI
- [ ] Retry appends error output, doesn't just re-run blindly
- [ ] Timeout kills runaway LLM processes
- [ ] Notifications fire on both success and failure
- [ ] Agent resets working directory between runs (git checkout, clean state)
