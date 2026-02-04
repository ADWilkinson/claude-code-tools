# Firebase/GCloud Logs Skill

Read logs from Firebase Cloud Functions and GCloud for debugging.

## Usage

When user runs `/logs`, ask what they want to see:
- Arbitrage bot logs (buy bot, delegate bot)
- USDCtoFiat function logs (notifications, twitter, telegram)
- Peerlytics function logs (analytics sync, relay sync)

## Project

```
Firebase Project: peerlyticsapp
Region: us-central1
```

## Commands

### Arbitrage Bot Logs

```bash
# Buy bot logs (Cloud Run)
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="arbBuyBot"' \
  --project peerlyticsapp --limit=50 --format="table(timestamp,textPayload)"

# Delegate bot logs
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="arbDelegateBot"' \
  --project peerlyticsapp --limit=50 --format="table(timestamp,textPayload)"

# Or via Firebase CLI
firebase functions:log --only arbBuyBot
firebase functions:log --only arbDelegateBot
```

### USDCtoFiat Function Logs

```bash
# All usdctofiat functions
firebase functions:log --only usdctofiat

# Specific functions
firebase functions:log --only sendPushNotification
firebase functions:log --only twitterBot
firebase functions:log --only telegramBot
```

### Peerlytics Function Logs

```bash
# Analytics sync (runs every 30 min)
firebase functions:log --only syncAnalytics

# Relay sync (runs every 4 hours)
firebase functions:log --only syncRelayData
```

### Filtered Queries

```bash
# Errors only
gcloud logging read \
  'resource.labels.service_name="arbBuyBot" AND severity>=ERROR' \
  --project peerlyticsapp --limit=20

# Last hour
gcloud logging read \
  'resource.labels.service_name="arbBuyBot" AND timestamp>="2024-01-01T00:00:00Z"' \
  --project peerlyticsapp --limit=50

# Search for specific text
gcloud logging read \
  'resource.labels.service_name="arbBuyBot" AND textPayload=~"Intent"' \
  --project peerlyticsapp --limit=50

# JSON structured logs (jsonPayload)
gcloud logging read \
  'resource.labels.service_name="arbBuyBot" AND jsonPayload.message=~"opportunity"' \
  --project peerlyticsapp --limit=50
```

## Log Prefixes

The arbitrage-bot uses consistent prefixes:
- `[Indexer]` - Indexer queries and cache state
- `[Intent]` - Intent signaling and fulfillment
- `[Sell]` - Rate updates and deposit management
- `[Buy]` - Opportunity detection and execution
- `[Leapfrog]` - Competitive rate defense
- `[Config]` - Dynamic config updates
- `[Discord]` - Notification sends

## Common Debugging Patterns

### Check Last Bot Activity
```bash
gcloud logging read \
  'resource.labels.service_name="arbBuyBot"' \
  --project peerlyticsapp --limit=5 --format="table(timestamp,textPayload)"
```

### Find Intent Events
```bash
gcloud logging read \
  'resource.labels.service_name="arbBuyBot" AND textPayload=~"Intent"' \
  --project peerlyticsapp --limit=20
```

### Check for Errors
```bash
gcloud logging read \
  'resource.labels.service_name="arbBuyBot" AND severity>=WARNING' \
  --project peerlyticsapp --limit=20
```

### Tail Live Logs
```bash
gcloud logging tail \
  'resource.labels.service_name="arbBuyBot"' \
  --project peerlyticsapp
```

## Notes

- Bot logs use `firebase-functions/logger` which outputs structured JSON
- Local dev uses console.log (check terminal output)
- Logs retain for 30 days by default
- Use `--format=json` for full log details including labels
