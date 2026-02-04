# Indexer Query Skill

Query the Envio GraphQL indexer for ZKP2P protocol data.

## Endpoint

```
https://indexer.hyperindex.xyz/8fd74dc/v1/graphql
```

## Usage

When user runs `/indexer`, ask what they want to query:
- Deposits (by user, by ID, active only)
- Intents (by hash, by user, pending/fulfilled)
- Orderbook (all active deposits with rates)
- Payment methods

## Common Queries

### Deposits by User
```graphql
query DepositsForUser($depositor: String!) {
  Deposit(where: { depositor: { _ilike: $depositor } }) {
    id
    depositId
    depositor
    delegate
    remainingDeposits
    outstandingIntentAmount
    acceptingIntents
    status
    updatedAt
  }
}
```

### Deposit by ID
```graphql
query DepositById($depositId: String!) {
  Deposit(where: { depositId: { _eq: $depositId } }) {
    id
    depositId
    depositor
    delegate
    escrowAddress
    remainingDeposits
    outstandingIntentAmount
    acceptingIntents
    intentAmountMin
    intentAmountMax
    status
    timestamp
    updatedAt
  }
}
```

### Active Deposits with Rates
```graphql
query ActiveDeposits {
  Deposit(where: { status: { _eq: "ACTIVE" }, acceptingIntents: { _eq: true } }) {
    depositId
    depositor
    delegate
    remainingDeposits
    outstandingIntentAmount
    updatedAt
  }
}
```

### Method Currencies (rates per deposit)
```graphql
query MethodCurrencies($depositId: String!) {
  MethodCurrency(where: { depositId: { _eq: $depositId } }) {
    depositId
    paymentMethodHash
    currencyCode
    minConversionRate
  }
}
```

### Intent by Hash
```graphql
query IntentByHash($intentHash: String!) {
  Intent(where: { intentHash: { _ilike: $intentHash } }) {
    intentHash
    owner
    toAddress
    amount
    fiatCurrency
    conversionRate
    status
    signalTimestamp
    fulfillTimestamp
  }
}
```

### User Pending Intents
```graphql
query UserPendingIntents($owner: String!) {
  Intent(where: { owner: { _ilike: $owner }, status: { _eq: "SIGNALED" } }) {
    intentHash
    amount
    depositId
    fiatCurrency
    conversionRate
    signalTimestamp
  }
}
```

## Key Types

```typescript
interface IndexerDeposit {
  id: string;                          // Indexer document ID
  depositId: string;                   // Numeric deposit ID
  depositor: string;                   // Creator address
  delegate: string | null;             // Delegate manager address
  remainingDeposits: string;           // Available USDC (6 decimals)
  outstandingIntentAmount: string;     // Locked in pending intents
  acceptingIntents: boolean;           // Active toggle
  status: 'ACTIVE' | 'CLOSED';
  updatedAt: string;                   // Unix seconds
}

interface IndexerIntent {
  intentHash: string;
  owner: string;
  amount: string;                      // USDC (6 decimals)
  status: 'SIGNALED' | 'FULFILLED' | 'PRUNED';
  signalTimestamp: string;             // Unix seconds
  fulfillTimestamp: string | null;
}
```

## Execution

Use curl or a Bash GraphQL query:
```bash
curl -X POST https://indexer.hyperindex.xyz/8fd74dc/v1/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "...", "variables": {...}}'
```

## Notes

- All addresses are case-insensitive (use `_ilike` for matching)
- Amounts are strings - use BigInt for math
- `remainingDeposits` and `outstandingIntentAmount` are 6-decimal USDC
- `minConversionRate` is 18-decimal
- Timestamps are Unix seconds (not milliseconds)
