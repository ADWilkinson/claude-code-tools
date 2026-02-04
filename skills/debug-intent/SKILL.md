# Debug Intent Skill

Track intent lifecycle and debug fulfillment issues.

## Usage

When user runs `/debug-intent [intentHash]`, perform full inspection:

1. Query intent state from indexer
2. Check status and timestamps
3. Calculate time since signal
4. Check related deposit
5. Look for on-chain events if needed

## Step 1: Query Intent

```bash
curl -s -X POST https://indexer.hyperindex.xyz/8fd74dc/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($hash: String!) { Intent(where: { intentHash: { _ilike: $hash } }) { intentHash owner toAddress amount depositId fiatCurrency conversionRate status signalTimestamp fulfillTimestamp prunedTimestamp } }",
    "variables": { "hash": "INTENT_HASH" }
  }' | jq '.data.Intent[0]'
```

## Step 2: Interpret Status

| Status | Meaning |
|--------|---------|
| `SIGNALED` | Pending - waiting for fulfillment |
| `FULFILLED` | Complete - USDC transferred |
| `PRUNED` | Expired/cancelled - funds returned to deposit |

## Step 3: Calculate Timing

```javascript
signalTime = new Date(parseInt(signalTimestamp) * 1000)
timeSinceSignal = (Date.now() - signalTime) / 1000 / 60  // minutes

// Intent expiry is typically 24 hours
if (timeSinceSignal > 1440 && status === 'SIGNALED') {
  // Intent may be prunable
}
```

## Step 4: Check Related Deposit

Use `/debug-deposit` with the `depositId` from the intent to verify:
- Deposit is still active
- Has sufficient liquidity
- `outstandingIntentAmount` includes this intent

## Step 5: Amount Verification

```javascript
// Intent amount is 6-decimal USDC
usdcAmount = parseInt(amount) / 1_000_000

// Conversion rate is 18-decimal
rate = parseInt(conversionRate) / 1e18
ratePercent = (1 - rate) * 100

// Fiat amount calculation
fiatAmount = usdcAmount / rate
```

## Intent Lifecycle

```
1. SIGNAL
   └─ User calls signalIntent() on escrow
   └─ Event: IntentSignaled(intentHash, amount, fiatCurrency, conversionRate)
   └─ Deposit's outstandingIntentAmount increases

2. FULFILL (happy path)
   └─ Depositor sends fiat, calls fulfillIntent()
   └─ USDC transfers to intent owner
   └─ Event: IntentFulfilled(intentHash)
   └─ Deposit's outstandingIntentAmount decreases

3. PRUNE (expiry path)
   └─ After expiry window (24h), anyone can call pruneIntent()
   └─ USDC returns to deposit's remainingDeposits
   └─ Event: IntentPruned(intentHash)
```

## Common Issues

### "Intent stuck in SIGNALED"
- Check time since signal (< 24h is normal wait time)
- Verify depositor is active (check their other fulfillments)
- Check deposit still has liquidity

### "Intent fulfilled but USDC not received"
- Verify `toAddress` is correct
- Check `fulfillTimestamp` exists
- Query on-chain transfer events

### "Intent shows wrong amount"
- Amount is 6-decimal, not human readable
- Divide by 1_000_000 for USDC value

### "Can't find intent by hash"
- Hash is case-insensitive but must include 0x prefix
- Try querying by owner address instead

## Query User's Intents

```bash
curl -s -X POST https://indexer.hyperindex.xyz/8fd74dc/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($owner: String!) { Intent(where: { owner: { _ilike: $owner } }, order_by: { signalTimestamp: desc }, limit: 20) { intentHash amount status signalTimestamp fulfillTimestamp depositId } }",
    "variables": { "owner": "0xUSER_ADDRESS" }
  }' | jq '.data.Intent'
```

## Bot State Check

If debugging arbitrage-bot intents, check Firestore:
```
Collection: arbitrageBotState/instances/instances/buy
Field: activeIntent

{
  "intentHash": "0x...",
  "amount": "1000000",
  "status": "SIGNALED",
  "signalTimestamp": 1704067200000,
  "platform": "revolut",
  "currency": "GBP"
}
```

## Output Format

Summarize findings:
```
Intent 0x1234...
├─ Status: SIGNALED (pending)
├─ Owner: 0xabc...
├─ To: 0xdef...
├─ Amount: 500 USDC
├─ Rate: 0.5% (conversionRate: 0.995)
├─ Currency: GBP
├─ Deposit: #123
├─ Signal time: 2024-01-15 10:30 UTC (2h 15m ago)
├─ Fulfill time: -
└─ Expected fiat: £502.51
```
