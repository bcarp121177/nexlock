# Testing DocuSeal Integration - Quick Start

## Current Status

✅ **Backend:** Fully implemented
✅ **UI:** Basic signature workflow added
⚠️ **Configuration:** Needs DocuSeal credentials

---

## What You Can Test Now

### 1. UI Changes (Ready Now)
Navigate to any trade in draft state: http://localhost:3000/trades/11

You should now see:
- 🔐 "Send for Digital Signature" button (primary, blue)
- "Or" divider
- "Send Simple Invitation" button (secondary)

### 2. Button Click Behavior

**Without DocuSeal Configured:**
Clicking "Send for Digital Signature" will show an error:
- "DocuSeal API key not configured" OR
- "DocuSeal template ID not configured"

This is expected! You need to configure DocuSeal first.

---

## Configure DocuSeal (30-60 minutes)

### Step 1: Create DocuSeal Account
1. Go to https://docuseal.com
2. Sign up for free account
3. Verify email

### Step 2: Get API Key
1. In DocuSeal dashboard → Settings → API
2. Click "Create API Key"
3. Copy the key (starts with `ds_`)
4. Save for Step 4

### Step 3: Create Template
1. In DocuSeal dashboard → Templates → Create Template
2. Name: "Nexlock Trade Agreement"
3. Add 2 roles:
   - **Seller** (signs first)
   - **Buyer** (signs second)
4. Set signing order: Sequential
5. Add merge fields (see below)
6. Add signature fields for both roles
7. Save and copy Template ID

**Required Merge Fields:**
```
{{seller_name}}
{{seller_email}}
{{buyer_name}}
{{buyer_email}}
{{item_name}}
{{item_description}}
{{price}}
{{trade_id}}
{{created_date}}
```

See `docs/DOCUSEAL_SETUP.md` for complete list of 22 fields.

### Step 4: Configure Webhook
1. DocuSeal dashboard → Settings → Webhooks
2. Add webhook URL:
   - Local dev with ngrok: `https://your-ngrok-url.ngrok.io/webhooks/docuseal`
   - Or skip for now (can test without webhooks initially)
3. Select events:
   - ✅ `submitter.signed`
   - ✅ `form.completed`
   - ✅ `submission.completed`
4. Copy webhook secret (starts with `whsec_`)

### Step 5: Add Credentials to Rails

```bash
EDITOR="code --wait" rails credentials:edit --environment development
```

Add this structure:

```yaml
docuseal:
  api_key: ds_your_api_key_from_step_2
  api_url: https://api.docuseal.com
  webhook_secret: whsec_your_secret_from_step_4  # Optional for initial testing
  trade_agreement_template_id: your_template_id_from_step_3
```

Save and close.

### Step 6: Restart Rails

```bash
# Stop current server (Ctrl+C)
bin/dev
```

Check logs for:
```
✓ DocuSeal configured successfully
  - API URL: https://api.docuseal.com
  - Template ID: 1234567
  - Webhook secret: configured
```

---

## Test Flow

### Full Test (With DocuSeal Configured)

1. **Start as Seller**
   - Go to: http://localhost:3000/trades/11
   - Click "🔐 Send for Digital Signature"
   - Confirm the alert
   - Trade should move to `awaiting_seller_signature`
   - DocuSeal iframe should load with signature form
   - Sign the document
   - Trade moves to `awaiting_buyer_signature`

2. **Switch to Buyer**
   - Open incognito/private window
   - Sign in as buyer (or buyer email if not registered)
   - Go to same trade: http://localhost:3000/trades/11
   - DocuSeal iframe should load for buyer
   - Sign the document
   - Trade moves to `awaiting_funding`
   - Signed PDF is stored

3. **Verify Completion**
   - Back in seller window, refresh page
   - Should see "View PDF" link under "Signed agreement"
   - Click to download signed PDF
   - Continue to funding workflow

### Quick Console Test (Without Full UI)

```ruby
# Rails console
trade = Trade.find(11)

# Check current state
trade.state  # Should be "draft"

# Send for signature
result = TradeService.send_for_signature(trade)

# Check result
puts result[:success] ? "✓ Success" : "✗ Error: #{result[:error]}"

# If successful, check signing URL
puts result[:signing_url]

# Open this URL in browser to test signing

# Check trade state
trade.reload.state  # Should be "awaiting_seller_signature"

# Check signature document was created
trade.trade_documents.count  # Should be 1
trade.trade_documents.last.status  # Should be "pending"

# Check signature records
trade.document_signatures.count  # Should be 2 (seller + buyer)
```

---

## Troubleshooting

### Error: "DocuSeal API key not configured"
**Solution:** Add credentials (see Step 5 above), restart Rails

### Error: "DocuSeal template ID not configured"
**Solution:** Create template (Step 3), add ID to credentials, restart

### DocuSeal iframe doesn't load
**Possible causes:**
1. Invalid API key → Check credentials
2. Invalid template ID → Verify in DocuSeal dashboard
3. Browser blocking iframe → Check console for errors
4. CORS issues → Verify `api.docuseal.com` in allowed_redirect_hosts.rb (already configured)

### Button does nothing / no error
**Solution:** Check Rails logs for errors:
```bash
tail -f log/development.log
```

### Trade doesn't progress after signing
**Without webhooks configured:**
- This is expected - webhooks trigger state transitions
- Need to set up ngrok and configure webhook (Step 4)

**With webhooks configured:**
- Check Rails logs for webhook deliveries
- Check DocuSeal dashboard → Webhooks → Delivery logs
- Verify webhook secret matches

---

## Testing Without DocuSeal (Console Only)

You can test state transitions without DocuSeal:

```ruby
trade = Trade.find(11)

# Manually trigger transitions (bypasses DocuSeal)
trade.signature_sent_at = Time.current
trade.signature_deadline_at = 7.days.from_now
trade.send_for_signature!  # This will fail without DocuSeal config

# To test state machine only (skip DocuSeal):
trade.update_column(:state, "awaiting_seller_signature")
trade.seller_signs!  # Moves to awaiting_buyer_signature
trade.buyer_signs!   # Moves to awaiting_funding
```

---

## Next Steps After Basic Testing

1. **Test webhook flow with ngrok**
   - Install ngrok: `brew install ngrok`
   - Start tunnel: `ngrok http 3000`
   - Update webhook URL in DocuSeal dashboard
   - Test full signature flow with state transitions

2. **Test deadline expiration**
   - Create signature request
   - Manually update deadline:
     ```ruby
     trade.update(signature_deadline_at: 1.minute.from_now)
     ```
   - Wait 2 minutes
   - Run job manually:
     ```ruby
     SignatureDeadlineCheckJob.perform_now
     ```
   - Verify trade moves to `signature_deadline_missed`

3. **Test cancellation**
   - Start signature process
   - Click "Cancel Signature Request"
   - Verify returns to draft state

4. **Test retry after deadline**
   - Let deadline expire (or force with console)
   - Click "Retry Signature Process"
   - Verify returns to draft state
   - Try sending again

---

## Production Deployment Checklist

Before deploying to production:

- [ ] Create production DocuSeal account
- [ ] Create production template (copy from development)
- [ ] Configure production webhook URL
- [ ] Add production credentials to Rails
- [ ] Test on staging first
- [ ] Monitor webhook deliveries
- [ ] Set up error alerts for failed webhooks
- [ ] Document runbook for common issues

---

## Support & Resources

- **Setup Guide:** `docs/DOCUSEAL_SETUP.md`
- **Workflow Comparison:** `docs/WORKFLOW_COMPARISON.md`
- **Implementation Status:** `docs/DOCUSEAL_IMPLEMENTATION_STATUS.md`
- **DocuSeal Docs:** https://docs.docuseal.com
- **DocuSeal API:** https://docs.docuseal.com/api
- **Webhook Guide:** https://docs.docuseal.com/webhooks

---

## Quick Reference

### States
- `draft` → Ready to send
- `awaiting_seller_signature` → Seller needs to sign
- `awaiting_buyer_signature` → Buyer needs to sign
- `signature_deadline_missed` → Expired, can retry
- `awaiting_funding` → Both signed, ready for payment

### Routes
- `POST /trades/:id/send_for_signature` - Initiate
- `GET /trades/:id/signing_url` - Get DocuSeal URL (AJAX)
- `POST /trades/:id/cancel_signature_request` - Cancel
- `POST /trades/:id/retry_signature` - Retry after expiration
- `POST /webhooks/docuseal` - Webhook endpoint

### Console Helpers
```ruby
# Check configuration
Rails.application.config.x.docuseal.api_key.present?

# Find trades in signature flow
Trade.where(state: [:awaiting_seller_signature, :awaiting_buyer_signature])

# Check deadline expirations
Trade.where("signature_deadline_at < ?", Time.current)

# Manual state transitions (testing only)
trade.seller_signs!
trade.buyer_signs!
```
