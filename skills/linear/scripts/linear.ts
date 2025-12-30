#!/usr/bin/env npx tsx

/**
 * Linear CLI for Claude Code
 * Author: Andrew Wilkinson (github.com/ADWilkinson)
 *
 * Usage:
 *   npx tsx linear.ts my-tasks
 *   npx tsx linear.ts in-progress
 *   npx tsx linear.ts create "Task title" [--assignee me] [--team TEAM]
 *   npx tsx linear.ts done ISSUE-ID
 *   npx tsx linear.ts start ISSUE-ID
 *   npx tsx linear.ts show ISSUE-ID
 *   npx tsx linear.ts comment ISSUE-ID "Comment text"
 */

import { LinearClient } from '@linear/sdk';

const API_KEY = process.env.LINEAR_API_KEY;

if (!API_KEY) {
  console.error('ERROR: LINEAR_API_KEY not set\n');
  console.error('Add to ~/.zshrc:');
  console.error('  export LINEAR_API_KEY="lin_api_..."');
  console.error('\nGet your key from: Linear → Settings → Security & access → Personal API keys');
  process.exit(1);
}

const client = new LinearClient({ apiKey: API_KEY });

type Priority = 0 | 1 | 2 | 3 | 4;

const PRIORITY_LABELS: Record<Priority, string> = {
  0: 'None',
  1: 'Urgent',
  2: 'High',
  3: 'Medium',
  4: 'Low',
};

function formatPriority(priority: number): string {
  return PRIORITY_LABELS[priority as Priority] || 'None';
}

function formatTable(issues: Array<{ id: string; title: string; state: string; priority: number }>) {
  if (issues.length === 0) {
    console.log('No issues found.');
    return;
  }

  console.log('ID        | Title                              | State        | Priority');
  console.log('----------|------------------------------------|--------------|---------');

  for (const issue of issues) {
    const id = issue.id.padEnd(9);
    const title = issue.title.length > 34 ? issue.title.slice(0, 31) + '...' : issue.title.padEnd(34);
    const state = issue.state.padEnd(12);
    const priority = formatPriority(issue.priority);
    console.log(`${id} | ${title} | ${state} | ${priority}`);
  }
}

async function getMyTasks() {
  const me = await client.viewer;
  const issues = await client.issues({
    filter: {
      assignee: { id: { eq: me.id } },
      state: { type: { nin: ['completed', 'canceled'] } }
    }
  });

  const formatted = await Promise.all(
    issues.nodes.map(async (issue) => ({
      id: issue.identifier,
      title: issue.title,
      state: (await issue.state)?.name || 'Unknown',
      priority: issue.priority,
    }))
  );

  formatTable(formatted);
}

async function getInProgress() {
  const me = await client.viewer;
  const issues = await client.issues({
    filter: {
      assignee: { id: { eq: me.id } },
      state: { type: { eq: 'started' } }
    }
  });

  const formatted = await Promise.all(
    issues.nodes.map(async (issue) => ({
      id: issue.identifier,
      title: issue.title,
      state: (await issue.state)?.name || 'Unknown',
      priority: issue.priority,
    }))
  );

  formatTable(formatted);
}

async function createTask(title: string, assignToMe: boolean, teamKey?: string) {
  const me = await client.viewer;

  // Get team - use provided key or find default
  let team;
  if (teamKey) {
    team = await client.team(teamKey);
  } else {
    const teams = await client.teams();
    team = teams.nodes[0];
    if (!team) {
      console.error('ERROR: No teams found in your workspace');
      process.exit(1);
    }
  }

  // Get appropriate state
  const states = await team.states();
  let targetState;

  if (assignToMe) {
    targetState = states.nodes.find(s => s.name.toLowerCase() === 'todo');
  } else {
    targetState = states.nodes.find(s => s.name.toLowerCase() === 'backlog');
  }

  if (!targetState) {
    targetState = states.nodes[0];
  }

  const issuePayload = await client.createIssue({
    teamId: team.id,
    title,
    stateId: targetState?.id,
    assigneeId: assignToMe ? me.id : undefined,
  });

  const issue = await issuePayload.issue;
  if (issue) {
    console.log(`Created: ${issue.identifier} - ${issue.title}`);
    console.log(`State: ${assignToMe ? 'Todo' : 'Backlog'}`);
    console.log(`Assigned: ${assignToMe ? 'You' : 'Unassigned'}`);
  }
}

async function updateState(issueId: string, targetStateName: string) {
  let issue;
  try {
    issue = await client.issue(issueId.toUpperCase());
  } catch {
    console.error(`ERROR: Issue ${issueId} not found`);
    process.exit(1);
  }

  // Get team states
  const team = await issue.team;
  if (!team) {
    console.error('ERROR: Could not find team for issue');
    process.exit(1);
  }

  const states = await team.states();
  const targetState = states.nodes.find(
    s => s.name.toLowerCase() === targetStateName.toLowerCase()
  );

  if (!targetState) {
    console.error(`ERROR: State "${targetStateName}" not found`);
    console.log('Available states:', states.nodes.map(s => s.name).join(', '));
    process.exit(1);
  }

  await issue.update({ stateId: targetState.id });
  console.log(`${issue.identifier} → ${targetState.name}`);
}

async function showIssue(issueId: string) {
  let issue;
  try {
    issue = await client.issue(issueId.toUpperCase());
  } catch {
    console.error(`ERROR: Issue ${issueId} not found`);
    process.exit(1);
  }

  const state = await issue.state;
  const assignee = await issue.assignee;
  const team = await issue.team;
  const labels = await issue.labels();

  console.log(`${issue.identifier}: ${issue.title}`);
  console.log('─'.repeat(50));
  console.log(`Team:     ${team?.name || 'Unknown'}`);
  console.log(`State:    ${state?.name || 'Unknown'}`);
  console.log(`Priority: ${formatPriority(issue.priority)}`);
  console.log(`Assignee: ${assignee?.name || 'Unassigned'}`);
  console.log(`Labels:   ${labels.nodes.map(l => l.name).join(', ') || 'None'}`);
  console.log(`Created:  ${issue.createdAt.toLocaleDateString()}`);

  if (issue.description) {
    console.log('─'.repeat(50));
    console.log(issue.description);
  }
}

async function addComment(issueId: string, body: string) {
  let issue;
  try {
    issue = await client.issue(issueId.toUpperCase());
  } catch {
    console.error(`ERROR: Issue ${issueId} not found`);
    process.exit(1);
  }

  await client.createComment({
    issueId: issue.id,
    body,
  });

  console.log(`Comment added to ${issue.identifier}`);
}

async function main() {
  const [command, ...args] = process.argv.slice(2);

  if (!command) {
    console.log('Linear CLI - Commands:');
    console.log('  my-tasks              List your assigned issues');
    console.log('  in-progress           List issues you\'re working on');
    console.log('  create "title"        Create issue (add --assignee me to assign)');
    console.log('  done ISSUE-ID         Mark issue as done');
    console.log('  start ISSUE-ID        Start working on issue');
    console.log('  show ISSUE-ID         Show issue details');
    console.log('  comment ISSUE-ID "text"  Add comment');
    process.exit(0);
  }

  switch (command) {
    case 'my-tasks':
      await getMyTasks();
      break;

    case 'in-progress':
      await getInProgress();
      break;

    case 'create': {
      const title = args[0];
      if (!title) {
        console.error('ERROR: Title required');
        console.error('Usage: create "Task title" [--assignee me] [--team TEAM]');
        process.exit(1);
      }
      const assignToMe = args.includes('--assignee') && args[args.indexOf('--assignee') + 1] === 'me';
      const teamIdx = args.indexOf('--team');
      const teamKey = teamIdx !== -1 ? args[teamIdx + 1] : undefined;
      await createTask(title, assignToMe, teamKey);
      break;
    }

    case 'done':
      if (!args[0]) {
        console.error('ERROR: Issue ID required');
        process.exit(1);
      }
      await updateState(args[0], 'Done');
      break;

    case 'start':
      if (!args[0]) {
        console.error('ERROR: Issue ID required');
        process.exit(1);
      }
      await updateState(args[0], 'In Progress');
      break;

    case 'show':
      if (!args[0]) {
        console.error('ERROR: Issue ID required');
        process.exit(1);
      }
      await showIssue(args[0]);
      break;

    case 'comment':
      if (!args[0] || !args[1]) {
        console.error('ERROR: Issue ID and comment text required');
        console.error('Usage: comment ISSUE-ID "Comment text"');
        process.exit(1);
      }
      await addComment(args[0], args[1]);
      break;

    default:
      console.error(`Unknown command: ${command}`);
      console.error('Run without arguments to see available commands');
      process.exit(1);
  }
}

main().catch((error) => {
  console.error('Error:', error.message);
  process.exit(1);
});
