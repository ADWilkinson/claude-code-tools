# Debug Deposit Skill

Comprehensive deposit inspection for debugging issues.

## Usage

When user runs `/debug-deposit [depositId]`, perform a full inspection:

1. Query indexer for deposit state
2. Calculate real liquidity
3. Check delegate status
4. Find related intents
5. Check method currencies (rates)

## Step 1: Query Deposit

```bash
curl -s -X POST https://indexer.hyperindex.xyz/8fd74dc/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($id: String!) { Deposit(where: { depositId: { _eq: $id } }) { id depositId depositor delegate escrowAddress remainingDeposits outstandingIntentAmount acceptingIntents intentAmountMin intentAmountMax status timestamp updatedAt } }",
    "variables": { "id": "DEPOSIT_ID" }
  }' | jq '.data.Deposit[0]'
```

## Step 2: Calculate Real Liquidity

```
availableLiquidity = remainingDeposits - outstandingIntentAmount
```

Both values are 6-decimal USDC strings. Convert to readable:
```
USDC = value / 1_000_000
```

## Step 3: Check Status

| Field | Good State | Problem State |
|-------|------------|---------------|
| `status` | `ACTIVE` | `CLOSED` = deposit withdrawn |
| `acceptingIntents` | `true` | `false` = paused |
| `remainingDeposits` | > 0 | 0 = empty |
| `outstandingIntentAmount` | 0 or low | High = funds locked in intents |

## Step 4: Check Delegate

```
delegate: null        → User-managed deposit
delegate: 0x...       → Delegated to that address
```

Bot addresses:
- Buy bot: Check `BOT_ADDRESS` in arbitrage-bot config
- Delegate bot: Check `DELEGATE_BOT_ADDRESS`

## Step 5: Query Method Currencies (Rates)

```bash
curl -s -X POST https://indexer.hyperindex.xyz/8fd74dc/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($id: String!) { MethodCurrency(where: { depositId: { _eq: $id } }) { paymentMethodHash currencyCode minConversionRate } }",
    "variables": { "id": "DEPOSIT_ID" }
  }' | jq '.data.MethodCurrency'
```

Rate calculation:
```
rate% = (1 - minConversionRate / 1e18) * 100
```

Example: `minConversionRate = 995000000000000000` → rate = 0.5%

## Step 6: Check Related Intents

```bash
curl -s -X POST https://indexer.hyperindex.xyz/8fd74dc/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query($id: String!) { Intent(where: { depositId: { _eq: $id } }, order_by: { signalTimestamp: desc }, limit: 10) { intentHash owner amount status signalTimestamp fulfillTimestamp } }",
    "variables": { "id": "DEPOSIT_ID" }
  }' | jq '.data.Intent'
```

## Common Issues

### "Deposit shows liquidity but can't buy"
- Check `acceptingIntents` is true
- Check `status` is ACTIVE
- Check `intentAmountMin/Max` bounds

### "Deposit stuck with outstanding amount"
- Query pending intents (status: SIGNALED)
- Intents older than 24h may need pruning

### "Can't update delegated deposit rate"
- Verify caller is the `delegate` address
- Check escrow contract permissions

### "Deposit not appearing in orderbook"
- Check `status === 'ACTIVE'`
- Check `acceptingIntents === true`
- Check `remainingDeposits > intentAmountMin`

## Staleness Check

```
currentTime = Date.now() / 1000
staleness = currentTime - parseInt(updatedAt)
```

- < 5 min: Fresh
- 5-35 min: Normal
- \> 35 min: Potentially stale (peerlytics shows warning)

## Output Format

Summarize findings:
```
Deposit #123
├─ Status: ACTIVE, accepting intents
├─ Depositor: 0x1234...
├─ Delegate: 0x5678... (delegated)
├─ Liquidity: 1,000 USDC (remaining) - 200 USDC (locked) = 800 USDC available
├─ Rates: GBP 0.5%, EUR 0.3%
├─ Bounds: min 10 USDC, max 500 USDC
├─ Last updated: 5 min ago
└─ Pending intents: 1 (200 USDC)
```
