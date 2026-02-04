# Bot State Skill

Inspect arbitrage-bot state in Firestore for debugging.

## Usage

When user runs `/bot-state`, ask which instance:
- `buy` - Buy bot (monitors opportunities, signals intents)
- `delegate` - Delegate bot (manages delegated deposits, updates rates)

Then fetch and display current state.

## Firestore Paths

```
Project: peerlyticsapp

Instance State:
  arbitrageBotState/instances/instances/{buy|delegate}

Global State:
  arbitrageBotState/global

Global Config (overrides):
  arbitrageBotConfig/global

Instance Config (overrides):
  arbitrageBotConfig/instances/instances/{buy|delegate}/overrides
```

## Fetch State via Firebase CLI

```bash
# Requires firebase-tools and project access
firebase firestore:get arbitrageBotState/instances/instances/buy --project peerlyticsapp
firebase firestore:get arbitrageBotState/global --project peerlyticsapp
```

Or use the Firebase Console directly:
https://console.firebase.google.com/project/peerlyticsapp/firestore

## Instance State Schema

```typescript
type InstanceState = {
  // Active intent being tracked
  activeIntent: {
    intentHash: string;
    amount: string;           // BigInt as string
    depositId: string;
    platform: 'revolut' | 'monzo';
    currency: 'GBP' | 'EUR' | 'USD';
    status: 'SIGNALED' | 'FULFILLED';
    signalTimestamp: number;  // Unix ms
  } | null;

  // Scan timestamps
  lastBuyScanAt: number;      // Unix ms
  lastSellCycleAt: number;

  // Sell cycle stats
  sellStats: {
    cycleCount: number;
    lastRunDurationMs: number;
  };

  // Tracked deposits
  trackedDepositIds: string[];      // User's own deposits
  delegatedDepositIds: string[];    // Deposits delegated to bot

  // Leapfrog defense state
  leapfrogState?: {
    [depositId: string]: {
      exchangeCount: number;
      lastCounterRate: number;
      lastCounterTime: number;
      warBackoffUntil?: number;
    };
  };

  // Session stats
  sessionStats?: {
    intentsSignaled: number;
    intentsFulfilled: number;
    usdcAcquired: string;      // BigInt as string
    startedAt: number;
  };

  // Heartbeat
  lastHeartbeat?: number;
};
```

## Global State Schema

```typescript
type GlobalState = {
  // Event log tracking
  lastBlockProcessed: number;
  lastIntentScanAt: number;
  lastSellEventScanAt: number;

  // Dynamic config per currency
  dynamicConfig: {
    [currency: string]: {
      minDiscountPercent: number;
      rateFloorMargin: number;
      peakPercentile: number;
      offPeakPercentile: number;
      lastAnalysis: number;
      lastResult: {
        fillRate: number;
        discountP85: number;
        recommendedFloor: number;
      };
    };
  };
  lastDynamicConfigAt: number;
};
```

## Key Things to Check

### Buy Bot Health
```
✓ lastBuyScanAt within last 5 minutes
✓ activeIntent is null (not stuck) or recent
✓ lastHeartbeat within last 4 hours
```

### Delegate Bot Health
```
✓ lastSellCycleAt within last 5 minutes
✓ delegatedDepositIds populated
✓ sellStats.cycleCount incrementing
```

### Stuck Intent Detection
```
If activeIntent exists:
  - Check signalTimestamp age
  - Query indexer for current status
  - If FULFILLED in indexer but still in state → state sync issue
```

### Leapfrog War Detection
```
If leapfrogState[depositId].warBackoffUntil > now:
  - Bot is in backoff mode (1 hour)
  - Won't counter-update rates

If exchangeCount >= 5:
  - War detected, backoff triggered
```

### Dynamic Config Check
```
dynamicConfig[currency].lastAnalysis should be < 4 hours old
Check lastResult.recommendedFloor matches current rates
```

## Local Cache Files

When running locally (not Firebase), state is in JSON files:

```
apps/arbitrage-bot/cache/
├─ indexer-state.json     # Deposit cache with timestamps
├─ leapfrog-state.json    # Leapfrog defense state
└─ lp-strategy-state.json # LP strategy state
```

## Common Issues

### "Bot not buying"
1. Check `lastBuyScanAt` is recent
2. Check `activeIntent` is null (not stuck on old intent)
3. Check logs for opportunity filtering reasons

### "Bot not updating rates"
1. Check `lastSellCycleAt` is recent
2. Check `delegatedDepositIds` includes the deposit
3. Check leapfrog state for war backoff

### "State out of sync"
1. Compare `activeIntent` status with indexer
2. If mismatch, bot may need restart to resync
3. Check for errors in logs around state saves

### "Config not applying"
1. Check `arbitrageBotConfig/global` for overrides
2. Check instance-specific overrides
3. Verify override key names match expected format

## Output Format

```
Buy Bot State
├─ Status: Healthy
├─ Last scan: 2 min ago
├─ Active intent: None
├─ Tracked deposits: 3
├─ Session stats:
│   ├─ Intents: 5 signaled, 4 fulfilled
│   └─ USDC acquired: 2,500
└─ Heartbeat: 1h ago

Delegate Bot State
├─ Status: Healthy
├─ Last cycle: 1 min ago (took 1.2s)
├─ Delegated deposits: 8
├─ Cycle count: 1,247
└─ Leapfrog state:
    └─ Deposit #123: 2 exchanges, no war
```
