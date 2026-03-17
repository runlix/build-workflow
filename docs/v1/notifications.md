# Release Notifications

The build-workflow system can send automated notifications when releases complete using Telegram Bot API.

## Features

- **Telegram Bot Integration**: Simple, free notifications via Telegram
- **Markdown Formatting**: Rich formatted messages with links
- **Conditional**: Only sends for versioned services (not SHA-based base images)
- **Non-blocking**: Notification failures don't block the release

---

## Telegram Notifications

### Why Telegram?

- ✅ **Free**: No costs, unlimited messages
- ✅ **Simple Setup**: Create bot in 2 minutes
- ✅ **No Verification**: No business account needed
- ✅ **Rich Formatting**: Markdown support with links
- ✅ **Mobile + Desktop**: Apps for all platforms
- ✅ **Group Support**: Send to channels or groups

---

## Setup Instructions

### Step 1: Create a Telegram Bot

1. **Open Telegram** and search for `@BotFather`
2. **Start a chat** with BotFather
3. **Send**: `/newbot`
4. **Follow prompts**:
   - Enter bot name: `MyProject Release Bot`
   - Enter bot username: `myproject_release_bot` (must end in `_bot`)
5. **Copy the bot token** (looks like `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### Step 2: Get Your Chat ID

**Option A: Personal Messages**
1. Search for `@userinfobot` on Telegram
2. Start a chat and send any message
3. The bot will reply with your **Chat ID** (e.g., `123456789`)

**Option B: Group/Channel**
1. Add your bot to the group/channel
2. Send a test message in the group
3. Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
4. Look for `"chat":{"id":-123456789}` in the response
5. The chat ID is the number (negative for groups)

### Step 3: Configure GitHub Secrets

```bash
# Add bot token
gh secret set TELEGRAM_BOT_TOKEN --body "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"

# Add chat ID
gh secret set TELEGRAM_CHAT_ID --body "123456789"

# Or via GitHub UI:
# Settings → Secrets and variables → Actions → New repository secret
```

### Step 4: Test the Notification

1. Trigger a release workflow
2. Check your Telegram chat for the notification
3. You should see a formatted message with release details

---

## Notification Format

The Telegram notification includes:

```
🎉 Docker Release Complete

Service: radarr
Version: v5.2.1
Commit: abc1234 (link)

Manifests Created:
v5.2.1, v5.2.1-debug, latest

Registry:
ghcr.io/runlix/radarr

[View Workflow Run] (clickable link)
```

**Features**:
- 🎉 Emoji for visual distinction
- 📝 **Service name** and **version**
- 🔗 **Clickable commit link** to GitHub
- 🏷️ **Manifests created** (comma-separated tags)
- 📦 **Registry location** for pull commands
- 🔗 **Workflow link** to view logs

---

## Customization

### Change Message Format

Edit `.github/workflows/build-images-rebuild.yml` lines 1126-1147:

```bash
MESSAGE=$(cat <<EOF
🎉 *Docker Release Complete*

*Service:* \`$SERVICE_NAME\`
*Version:* \`$VERSION\`
*Commit:* [\`$SHORT_SHA\`](${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }})

*Manifests Created:*
\`$MANIFESTS\`

[View Workflow Run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})
EOF
)
```

**Telegram Markdown Syntax**:
- `*bold*` → **bold**
- `_italic_` → _italic_
- `` `code` `` → `code`
- `[text](url)` → clickable link

### Send to Multiple Chats

```bash
# In workflow, send to multiple recipients
for CHAT_ID in "${{ secrets.TELEGRAM_CHAT_DEV }}" "${{ secrets.TELEGRAM_CHAT_PROD }}"; do
  curl -s -X POST "https://api.telegram.org/bot${{ secrets.TELEGRAM_BOT_TOKEN }}/sendMessage" \
    -d "chat_id=$CHAT_ID" \
    -d "text=$MESSAGE" \
    -d "parse_mode=Markdown"
done
```

### Add Custom Buttons

Telegram supports inline buttons:

```bash
# Add buttons to message
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": \"$CHAT_ID\",
    \"text\": \"$MESSAGE\",
    \"parse_mode\": \"Markdown\",
    \"reply_markup\": {
      \"inline_keyboard\": [[
        {
          \"text\": \"View Workflow\",
          \"url\": \"$WORKFLOW_URL\"
        },
        {
          \"text\": \"View Commit\",
          \"url\": \"$COMMIT_URL\"
        }
      ]]
    }
  }"
```

### Conditional Notifications

**Only notify for production releases**:

```yaml
- name: Send release notification
  if: |
    needs.parse-matrix.outputs.version != '' &&
    !contains(needs.parse-matrix.outputs.version, '-rc') &&
    !contains(needs.parse-matrix.outputs.version, '-beta')
```

**Notify different chats based on severity**:

```bash
# Major version (v2.0.0) → production chat
# Minor/patch (v2.1.0, v2.1.1) → dev chat
if [[ "$VERSION" =~ ^v[0-9]+\.0\.0$ ]]; then
  CHAT_ID="${{ secrets.TELEGRAM_CHAT_PROD }}"
else
  CHAT_ID="${{ secrets.TELEGRAM_CHAT_DEV }}"
fi
```

---

## Troubleshooting

### Notification Not Sent

**Check secrets are configured**:
```bash
gh secret list | grep TELEGRAM
```

Should show:
```
TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID
```

**Check workflow logs**:
- Look for "Send release notification" step
- Should see: "✅ Notification sent to Telegram"
- Or: "⚠️ TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not configured"

### Bot Not Responding

**Verify bot token**:
```bash
# Test API access
curl -s "https://api.telegram.org/bot<YOUR_TOKEN>/getMe"
```

Should return:
```json
{
  "ok": true,
  "result": {
    "id": 123456789,
    "is_bot": true,
    "first_name": "MyProject Release Bot",
    ...
  }
}
```

**Common issues**:
- Invalid bot token format
- Bot was deleted or blocked
- Token contains typos or extra spaces

### Messages Not Received

**Check chat ID**:
```bash
# Send test message
curl -s -X POST "https://api.telegram.org/bot<YOUR_TOKEN>/sendMessage" \
  -d "chat_id=<YOUR_CHAT_ID>" \
  -d "text=Test message"
```

**Common issues**:
- Wrong chat ID (positive vs negative for groups)
- Bot not added to group/channel
- User blocked the bot
- Bot kicked from group

### Markdown Formatting Issues

**Test message locally**:
```bash
MESSAGE="*Bold* _italic_ \`code\` [link](https://example.com)"

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=$MESSAGE" \
  -d "parse_mode=Markdown"
```

**Common issues**:
- Unescaped special characters: `_ * [ ] ( ) ~ > # + - = | { } . !`
- Invalid markdown syntax
- Use `parse_mode=MarkdownV2` for strict markdown (requires escaping)

### Specific Error Messages

**"Unauthorized" (401)**:
```json
{"ok":false,"error_code":401,"description":"Unauthorized"}
```

**Causes**:
- Token is invalid or revoked
- Token contains extra spaces/newlines
- Token format is incorrect

**Solution**:
```bash
# Verify token format (should be: NUMBER:ALPHANUMERIC)
echo "YOUR_TOKEN" | grep -E '^[0-9]+:[A-Za-z0-9_-]+$'

# Test token
curl -s "https://api.telegram.org/botYOUR_TOKEN/getMe"

# Update secret
gh secret set TELEGRAM_BOT_TOKEN --body "CORRECT_TOKEN"
```

**"Bad Request: chat not found" (400)**:
```json
{"ok":false,"error_code":400,"description":"Bad Request: chat not found"}
```

**Causes**:
- Chat ID is incorrect
- Bot is not member of group/channel
- User blocked the bot

**Solution**:
```bash
# Verify chat ID format (should be: number, possibly negative)
echo "123456789" | grep -E '^-?[0-9]+$'

# For groups: Verify bot is member
# Open Telegram → Group → Members → Check bot is listed

# For personal: Verify you started conversation with bot
# Send any message to bot first

# Test with correct chat ID
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=Test"
```

**"Forbidden: bot was blocked by the user" (403)**:
```json
{"ok":false,"error_code":403,"description":"Forbidden: bot was blocked by the user"}
```

**Solution**:
- Unblock the bot in Telegram
- Send `/start` to the bot
- Update chat ID if needed

**"Forbidden: bot is not a member of the group chat" (403)**:
```json
{"ok":false,"error_code":403,"description":"Forbidden: bot is not a member of the group chat"}
```

**Solution**:
- Add bot to group via "Add member"
- Grant appropriate permissions if it's a channel
- Verify bot wasn't removed

---

## Verification Commands

### Check All Secrets Are Configured

```bash
# List all secrets (values are masked)
gh secret list

# Expected output:
# TELEGRAM_BOT_TOKEN  Updated 2025-01-29
# TELEGRAM_CHAT_ID    Updated 2025-01-29
```

### Test Telegram Integration

```bash
# Set variables
BOT_TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"

# Test bot is active
curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe" | jq

# Test sending message
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=🧪 Test from $(hostname)" \
  -d "parse_mode=Markdown" | jq

# Check for "ok": true in response
```

### Verify Workflow Permissions

```bash
# Check workflow has required permissions
grep -A 5 "^permissions:" .github/workflows/*.yml
```

Expected:
```yaml
permissions:
  contents: write       # ✅ Required
  packages: write       # ✅ Required
  pull-requests: write  # ✅ Required (PR mode)
  actions: read         # ✅ Required
```

---

## Security Considerations

### Bot Token Protection

- ✅ **Store in GitHub Secrets** (encrypted at rest)
- ❌ **Never commit to repository** (visible in history)
- ❌ **Never log token** (visible in workflow logs)

**Token has full control of your bot** - treat it like a password!

### Token Rotation

Regenerate bot token periodically:

1. Message `@BotFather`
2. Send `/mybots`
3. Select your bot
4. Choose "API Token"
5. Select "Revoke current token"
6. Copy new token
7. Update GitHub secret: `gh secret set TELEGRAM_BOT_TOKEN --body "NEW_TOKEN"`

### Chat ID Privacy

- Chat IDs are not sensitive (can't be used without bot token)
- However, they reveal which groups/channels receive notifications
- Store in secrets for consistency

### Message Content

Avoid including sensitive data in notifications:
- ❌ API keys, passwords, tokens
- ❌ Internal URLs, IPs, secrets
- ❌ Customer data or PII
- ✅ Public registry URLs
- ✅ Public commit SHAs
- ✅ Version numbers

---

## Examples

### Minimal Notification

```bash
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=Released $SERVICE_NAME $VERSION"
```

### Rich Notification with HTML

```bash
MESSAGE="<b>🎉 Release Complete</b>

<b>Service:</b> <code>$SERVICE_NAME</code>
<b>Version:</b> <code>$VERSION</code>
<b>Commit:</b> <a href=\"$COMMIT_URL\">$SHORT_SHA</a>

<a href=\"$WORKFLOW_URL\">View Workflow</a>"

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=$MESSAGE" \
  -d "parse_mode=HTML"
```

### Silent Notification (No Sound)

```bash
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=$MESSAGE" \
  -d "parse_mode=Markdown" \
  -d "disable_notification=true"
```

### Thread/Reply to Previous Message

```bash
# Save message_id from previous notification
MESSAGE_ID="12345"

curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=New release available" \
  -d "reply_to_message_id=$MESSAGE_ID"
```

---

## Integration with CI/CD

### Argo CD

Include deployment command:

```bash
MESSAGE="$MESSAGE

*Deploy with ArgoCD:*
\`argocd app set $SERVICE_NAME --helm-set image.tag=$VERSION\`"
```

### Kubernetes

Include kubectl command:

```bash
MESSAGE="$MESSAGE

*Deploy to K8s:*
\`kubectl set image deployment/$SERVICE_NAME container=${REGISTRY}/${REGISTRY_ORG}/${SERVICE_NAME}:$VERSION\`"
```

### Docker Compose

Include compose pull command:

```bash
MESSAGE="$MESSAGE

*Update compose:*
\`docker-compose pull $SERVICE_NAME && docker-compose up -d $SERVICE_NAME\`"
```

---

## Advanced Features

### Pin Important Messages

```bash
# Send message and pin it
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=$MESSAGE" \
  -d "parse_mode=Markdown")

MESSAGE_ID=$(echo "$RESPONSE" | jq -r '.result.message_id')

curl -s -X POST "https://api.telegram.org/bot$TOKEN/pinChatMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "message_id=$MESSAGE_ID"
```

### Delete Old Messages

```bash
# Delete message by ID
curl -s -X POST "https://api.telegram.org/bot$TOKEN/deleteMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "message_id=$OLD_MESSAGE_ID"
```

### Send Files/Artifacts

```bash
# Send manifest file as document
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendDocument" \
  -F "chat_id=$CHAT_ID" \
  -F "document=@manifests-created.txt" \
  -F "caption=Release $VERSION manifests"
```

### Rate Limiting

Telegram allows:
- 30 messages per second to different chats
- 1 message per second to same chat

For high-frequency releases, add delay:

```bash
# Add 1 second delay between messages
sleep 1
```

---

## Comparison: Telegram vs Slack vs WhatsApp

| Feature | Telegram | Slack | WhatsApp |
|---------|----------|-------|----------|
| **Setup Complexity** | ⭐ Easy (2 min) | ⭐⭐ Medium (webhook) | ⭐⭐⭐⭐ Hard (business API) |
| **Cost** | Free | Free (limited) | Paid |
| **API Access** | Simple REST | Webhook | Complex |
| **Formatting** | Markdown/HTML | Block Kit | Limited |
| **Verification** | None | None | Business verification |
| **Rate Limits** | 30 msg/sec | Varies | Strict |
| **Mobile Apps** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Desktop Apps** | ✅ Yes | ✅ Yes | ✅ Limited |
| **Group Support** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Bots** | ✅ Native | ✅ Yes | ❌ Limited |

---

## FAQ

### Q: Can I use the same bot for multiple repositories?

**A**: Yes! Use different chat IDs for each repo/project:

```bash
# Repository 1
gh secret set TELEGRAM_CHAT_ID --body "123456789"

# Repository 2
gh secret set TELEGRAM_CHAT_ID --body "987654321"
```

### Q: How do I notify multiple people?

**A**: Create a Telegram group:

1. Create a new group in Telegram
2. Add all team members
3. Add your bot to the group
4. Get the group chat ID (negative number)
5. Use group chat ID in secrets

### Q: Can I disable notifications for specific services?

**A**: Yes, add condition to workflow:

```yaml
- name: Send release notification
  if: |
    needs.parse-matrix.outputs.version != '' &&
    env.SERVICE_NAME != 'test-service'
```

### Q: How do I test notifications without releasing?

**A**: Send manual test message:

```bash
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=🧪 Test notification from GitHub Actions"
```

### Q: What if Telegram API is down?

**A**: The workflow continues with `continue-on-error: true`. You'll see a warning in logs but the release completes successfully.

### Q: Can I use webhook instead of API calls?

**A**: Telegram doesn't support outgoing webhooks for bots. You must use the Bot API with POST requests.

---

## Migration from Slack

If you previously used Slack notifications:

### 1. Remove Slack Secrets

```bash
gh secret delete SLACK_WEBHOOK_URL
```

### 2. Add Telegram Secrets

```bash
gh secret set TELEGRAM_BOT_TOKEN --body "YOUR_BOT_TOKEN"
gh secret set TELEGRAM_CHAT_ID --body "YOUR_CHAT_ID"
```

### 3. Update Workflow

The workflow already uses Telegram - just configure the secrets!

### 4. Test

Trigger a release and verify you receive the Telegram notification.

---

## Support

For issues with notifications:

1. Check workflow logs for error messages
2. Test bot token with `getMe` API call
3. Verify chat ID with test message
4. Check bot is member of group/channel
5. Create issue in build-workflow repository

**Telegram Bot API Documentation**: https://core.telegram.org/bots/api
