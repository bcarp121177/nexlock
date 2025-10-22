# DocuSeal Digital Signature Integration - Setup Guide

## Overview

This guide walks through setting up the DocuSeal digital signature integration for legally binding trade agreements.

---

## Prerequisites

- DocuSeal account (sign up at https://docuseal.com)
- Access to Rails encrypted credentials
- Digital Ocean Spaces configured (already done ✓)

---

## Step 1: Configure DocuSeal Account

### 1.1 Create DocuSeal Account
1. Go to https://docuseal.com
2. Sign up for an account
3. Navigate to Settings → API

### 1.2 Get API Key
1. In DocuSeal dashboard, go to Settings → API
2. Create a new API key
3. Copy the API key (starts with `ds_`)
4. Save this for Step 2

### 1.3 Configure Webhook
1. In DocuSeal dashboard, go to Settings → Webhooks
2. Click "Add Webhook"
3. Set URL to: `https://yourdomain.com/webhooks/docuseal`
   - For local development with ngrok: `https://your-ngrok-url.ngrok.io/webhooks/docuseal`
4. Select events to send:
   - ✅ `submitter.signed`
   - ✅ `form.completed`
   - ✅ `submission.completed`
   - ✅ `submission.expired`
5. Copy the webhook secret (starts with `whsec_`)
6. Save this for Step 2

---

## Step 2: Configure Rails Credentials

### 2.1 Edit Development Credentials

```bash
EDITOR="code --wait" rails credentials:edit --environment development
```

Add the following structure:

```yaml
docuseal:
  api_key: ds_your_api_key_here
  api_url: https://api.docuseal.com
  webhook_secret: whsec_your_webhook_secret_here
  trade_agreement_template_id: your_template_id_here  # Add after Step 3
```

### 2.2 Edit Production Credentials

```bash
EDITOR="code --wait" rails credentials:edit --environment production
```

Add the same structure with production values.

---

## Step 3: Create DocuSeal Template

### 3.1 Create New Template
1. In DocuSeal dashboard, click "Templates"
2. Click "Create Template"
3. Name: "Nexlock Trade Agreement"
4. Upload a base PDF or create from scratch

### 3.2 Add Roles
1. Add 2 roles:
   - **Role 1:** "Seller" (signs first)
   - **Role 2:** "Buyer" (signs second)
2. Set signing order: **Sequential** (Seller → Buyer)

### 3.3 Add Merge Fields

Add the following merge fields to populate trade data:

**Party Information:**
- `{{seller_name}}` - Seller's full name
- `{{seller_email}}` - Seller's email
- `{{seller_address}}` - Full seller address
- `{{seller_city}}` - Seller city
- `{{seller_state}}` - Seller state
- `{{seller_zip}}` - Seller ZIP code
- `{{buyer_name}}` - Buyer's full name
- `{{buyer_email}}` - Buyer's email
- `{{buyer_address}}` - Full buyer address
- `{{buyer_city}}` - Buyer city
- `{{buyer_state}}` - Buyer state
- `{{buyer_zip}}` - Buyer ZIP code

**Item Details:**
- `{{item_name}}` - Item being traded
- `{{item_description}}` - Item description
- `{{item_category}}` - Item category
- `{{item_condition}}` - Item condition

**Financial Terms:**
- `{{price}}` - Trade price (formatted with $)
- `{{currency}}` - Currency (USD)
- `{{platform_fee}}` - Platform fee (formatted with $)
- `{{fee_split}}` - Who pays fee

**Trade Terms:**
- `{{inspection_window}}` - Inspection window (e.g., "48 hours")
- `{{trade_id}}` - Unique trade identifier
- `{{created_date}}` - Date trade was created

### 3.4 Add Interactive Fields
1. Add **Signature field** for Role 1 (Seller)
2. Add **Signature field** for Role 2 (Buyer)
3. Add **Date signed** fields (auto-filled)
4. Optional: Add name confirmation fields

### 3.5 Save and Get Template ID
1. Click "Save"
2. Copy the Template ID from the URL or template list
3. Update your credentials file with this template ID:

```bash
EDITOR="code --wait" rails credentials:edit --environment development
```

Update the `trade_agreement_template_id` value.

---

## Step 4: Test the Integration

### 4.1 Start Rails Server

```bash
bin/dev
```

Check the logs for the DocuSeal configuration message:

```
✓ DocuSeal configured successfully
  - API URL: https://api.docuseal.com
  - Template ID: 1234567
  - Webhook secret: configured
```

### 4.2 Test with Rake Task

Run the test task to verify API connectivity:

```bash
rails runner "
  trade = Trade.draft.first
  result = TradeService.send_for_signature(trade)
  puts result[:success] ? '✓ Success' : \"✗ Error: #{result[:error]}\"
"
```

### 4.3 Test Full Workflow

1. Create a new trade in the UI
2. Click "Send for Signature"
3. Complete seller signature in embedded iframe
4. Complete buyer signature (use different browser/incognito)
5. Verify signed PDF downloads

---

## Step 5: Local Development with Webhooks

### 5.1 Install ngrok

```bash
brew install ngrok
# or download from https://ngrok.com
```

### 5.2 Start ngrok Tunnel

```bash
ngrok http 3000
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

### 5.3 Update DocuSeal Webhook URL

1. Go to DocuSeal dashboard → Settings → Webhooks
2. Update webhook URL to: `https://abc123.ngrok.io/webhooks/docuseal`
3. Save

### 5.4 Test Webhooks

1. Create and send a trade for signature
2. Sign as seller
3. Check Rails logs for webhook delivery:

```
DocuSeal webhook received: submitter.signed
Signature recorded for seller
Trade 123 - Seller signed
```

---

## Step 6: Production Deployment

### 6.1 Pre-Deployment Checklist

- [ ] Production DocuSeal account created
- [ ] Production template created with correct merge fields
- [ ] Production webhook URL configured
- [ ] Production credentials file updated
- [ ] Webhook secret configured
- [ ] Digital Ocean Spaces credentials verified

### 6.2 Deploy Application

```bash
# Deploy with your preferred method (Kamal, Capistrano, etc.)
kamal deploy
```

### 6.3 Verify Configuration

```bash
# On production server
rails runner "
  config = Rails.application.config.x.docuseal
  puts 'API Key: ' + (config.api_key.present? ? '✓' : '✗')
  puts 'Template ID: ' + (config.trade_agreement_template_id.present? ? '✓' : '✗')
  puts 'Webhook Secret: ' + (config.webhook_secret.present? ? '✓' : '✗')
"
```

### 6.4 Test Production Workflow

1. Create test trade
2. Send for signature
3. Complete signatures
4. Verify PDF downloads
5. Check webhook deliveries in DocuSeal dashboard

---

## Troubleshooting

### Issue: "DocuSeal API key not configured"

**Solution:**
- Verify credentials are set correctly
- Restart Rails server after updating credentials
- Check `config/initializers/docuseal.rb` is loading

### Issue: DocuSeal iframe doesn't load

**Solution:**
- Check browser console for CORS errors
- Verify `api.docuseal.com` is in `config/initializers/allowed_redirect_hosts.rb`
- Clear browser cache

### Issue: Webhook not processing

**Solution:**
- Verify webhook URL is publicly accessible
- Check webhook secret matches in credentials
- Review Rails logs for signature verification failures
- Check DocuSeal dashboard for webhook delivery attempts

### Issue: Signed PDF not downloading

**Solution:**
- Verify Active Storage configuration
- Check Digital Ocean Spaces credentials
- Review logs for upload failures
- Ensure bucket permissions are correct

### Issue: Trade stuck in signature state

**Solution:**
- Check TradeDocument status: `TradeDocument.find_by(trade_id: X).status`
- Manually trigger state transition: `trade.buyer_signs!` (if appropriate)
- Check DocuSeal submission status via API
- Run deadline check job manually: `SignatureDeadlineCheckJob.perform_now`

---

## Monitoring

### Key Metrics to Track

1. **Signature completion rate**
   ```ruby
   completed = Trade.where(state: [:awaiting_funding, :funded]).count
   total_sent = Trade.where(state: [:awaiting_seller_signature, :awaiting_buyer_signature, :awaiting_funding, :funded]).count
   rate = (completed.to_f / total_sent * 100).round(2)
   ```

2. **Average time to complete signatures**
   ```ruby
   Trade.where.not(buyer_signed_at: nil)
        .average("EXTRACT(EPOCH FROM (buyer_signed_at - signature_sent_at)) / 3600")
   ```

3. **Deadline expiration rate**
   ```ruby
   expired = Trade.where(state: :signature_deadline_missed).count
   total = Trade.where.not(signature_sent_at: nil).count
   rate = (expired.to_f / total * 100).round(2)
   ```

### Logs to Monitor

- DocuSeal API errors
- Webhook processing failures
- Signature deadline expirations
- PDF download/upload failures

---

## Security Notes

- API keys are stored encrypted in Rails credentials
- Webhook signatures verified with HMAC SHA256
- Only buyer and seller can access signed documents
- Trades are locked during signature process
- IP addresses and user agents recorded for audit trail

---

## Support

- **DocuSeal Documentation:** https://docs.docuseal.com
- **DocuSeal Support:** support@docuseal.com
- **Webhook Debugging:** https://docs.docuseal.com/webhooks
- **API Reference:** https://docs.docuseal.com/api

---

## Appendix: Signature Workflow States

```
draft
  ↓ send_for_signature!
awaiting_seller_signature (locked)
  ↓ seller_signs! (via webhook)
awaiting_buyer_signature (locked)
  ↓ buyer_signs! (via webhook)
awaiting_funding (unlocked, PDF stored)
  ↓ (continue to funding flow)
```

**Alternate paths:**
- `signature_deadline_expired!` → `signature_deadline_missed`
- `cancel_signature_request!` → `draft`
- `restart_signature_process!` → `draft` (from deadline_missed)
