# Trade Workflow Comparison

## Two Available Workflows

### OLD Workflow (Simple Agreement) - Currently in UI
```
draft
  ↓ send_to_buyer (button exists)
  ↓ agree (both parties click "Agree")
awaiting_funding
  ↓ (payment flow)
funded
  ↓ ship
shipped
  ↓ mark_delivered
delivered_pending_confirmation
  ↓ confirm_receipt
inspection
  ↓ accept/reject
accepted/rejected
```

**Status:** ✅ Fully implemented in UI
**Use Case:** Quick trades without legal signatures

---

### NEW Workflow (DocuSeal Signatures) - Backend Complete, UI Missing
```
draft
  ↓ send_for_signature (NO BUTTON IN UI YET)
awaiting_seller_signature (locked)
  ↓ seller_signs! (via DocuSeal webhook)
awaiting_buyer_signature (locked)
  ↓ buyer_signs! (via DocuSeal webhook)
awaiting_funding (unlocked)
  ↓ (same as old workflow from here)
funded
  ↓ ship
shipped
  ... (rest same as old workflow)
```

**Status:** ⚠️ Backend complete, UI missing
**Use Case:** Legally binding trades with digital signatures

---

## What's Missing in the UI

### 1. Draft State - Need to Add
Line 209-230 in `app/views/trades/show.html.erb`

**Current:** Only shows "Send to Buyer" button
**Needed:** Add "Send for Signature" button as alternative

```erb
<% when "draft" %>
  <% if @is_seller %>
    <p class="text-sm text-app-muted mb-4">
      <%= t("trades.show.next_steps.ready_to_send", default: "Choose how to proceed with this trade.") %>
    </p>

    <!-- NEW: DocuSeal Signature Workflow -->
    <div class="space-y-3">
      <%= button_to t("trades.show.actions.send_for_signature", default: "Send for Digital Signature"),
                    send_for_signature_trade_path(@trade),
                    method: :post,
                    class: "btn-app-primary w-full",
                    data: { turbo_confirm: "This will send the trade for legally binding digital signatures. Continue?" } %>
      <p class="text-xs text-app-muted">Both you and the buyer will sign a legally binding agreement before funding.</p>
    </div>

    <div class="my-4 relative">
      <div class="absolute inset-0 flex items-center">
        <div class="w-full border-t border-app-subtle"></div>
      </div>
      <div class="relative flex justify-center text-xs uppercase">
        <span class="bg-app-card px-2 text-app-muted">Or</span>
      </div>
    </div>

    <!-- OLD: Simple Agreement Workflow -->
    <div class="space-y-3">
      <% unless @invitation_sent %>
        <%= button_to t("trades.show.actions.send_to_buyer", default: "Send Simple Invitation"),
                      send_to_buyer_trade_path(@trade),
                      method: :post,
                      class: "btn-app-secondary w-full" %>
        <p class="text-xs text-app-muted">Quick workflow without legal signatures.</p>
      <% else %>
        <p class="text-sm text-app-muted">Invitation sent. Waiting for buyer agreement.</p>
      <% end %>
    </div>
  <% end %>
```

### 2. Signature States - Completely Missing
Need to add cases for:
- `awaiting_seller_signature`
- `awaiting_buyer_signature`
- `signature_deadline_missed`

```erb
<% when "awaiting_seller_signature", "awaiting_buyer_signature" %>
  <% if @is_seller && @trade.awaiting_seller_signature? %>
    <!-- Seller needs to sign -->
    <p class="text-sm text-app-muted mb-4">Please review and sign the trade agreement below.</p>
    <div id="docuseal-container">
      <%= render "trades/docuseal_signature_form", trade: @trade %>
    </div>
  <% elsif @is_buyer && @trade.awaiting_buyer_signature? %>
    <!-- Buyer needs to sign -->
    <p class="text-sm text-app-muted mb-4">Please review and sign the trade agreement below.</p>
    <div id="docuseal-container">
      <%= render "trades/docuseal_signature_form", trade: @trade %>
    </div>
  <% else %>
    <!-- Waiting for other party -->
    <div class="flex items-center gap-3 p-4 bg-app-subtle rounded-lg">
      <svg class="animate-spin h-5 w-5 text-app-accent" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <div>
        <p class="font-medium">Waiting for <%= @trade.awaiting_seller_signature? ? "seller" : "buyer" %> to sign</p>
        <p class="text-sm text-app-muted">You'll be notified when it's your turn</p>
      </div>
    </div>
  <% end %>

  <% if @is_seller %>
    <div class="mt-4 pt-4 border-t border-app-subtle">
      <%= button_to "Cancel Signature Request",
                    cancel_signature_request_trade_path(@trade),
                    method: :post,
                    class: "btn-app-secondary",
                    data: { turbo_confirm: "Cancel the signature request? The trade will return to draft." } %>
    </div>
  <% end %>

<% when "signature_deadline_missed" %>
  <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
    <h4 class="font-medium text-red-900">Signature Deadline Missed</h4>
    <p class="text-sm text-red-700 mt-1">The signature request expired before both parties signed.</p>
  </div>

  <% if @is_seller %>
    <div class="mt-4">
      <%= button_to "Retry Signature Process",
                    retry_signature_trade_path(@trade),
                    method: :post,
                    class: "btn-app-primary" %>
    </div>
  <% else %>
    <p class="text-sm text-app-muted mt-4">Waiting for seller to restart the signature process.</p>
  <% end %>
```

### 3. DocuSeal Embed Partial - Missing
Need to create `app/views/trades/_docuseal_signature_form.html.erb`

### 4. Signed Agreement Download - Commented Out
Lines 83-89 need to be uncommented and fixed:

```erb
<% if @trade.signed_agreement_url.present? %>
  <div>
    <p class="text-xs uppercase tracking-wide text-app-muted"><%= t("trades.show.labels.agreement", default: "Signed agreement") %></p>
    <%= link_to t("trades.show.actions.view_agreement", default: "View PDF"),
                @trade.signed_agreement_url,
                target: "_blank",
                rel: "noopener",
                class: "mt-1 inline-flex text-sm text-app-accent hover:underline" %>
  </div>
<% end %>
```

---

## Testing Workflow - Step by Step

### Option 1: Test OLD Workflow (Already Works)
1. Go to trade in draft state: http://localhost:3000/trades/11
2. As seller, click "Send to Buyer"
3. As buyer (different browser/incognito), click "Agree to Terms"
4. Trade moves to `awaiting_funding`
5. Continue with funding/shipping flow

### Option 2: Test NEW Workflow (Need UI First)
1. Add UI changes (see below)
2. Configure DocuSeal credentials
3. Create DocuSeal template
4. As seller, click "Send for Digital Signature"
5. Sign in embedded DocuSeal iframe
6. As buyer, sign in embedded DocuSeal iframe
7. Trade moves to `awaiting_funding` with signed PDF
8. Download signed PDF
9. Continue with funding/shipping flow

---

## Quick Fix to Test DocuSeal Now

**Option A: Console Testing (Bypass UI)**
```ruby
# In Rails console
trade = Trade.find(11)
result = TradeService.send_for_signature(trade)

# Check result
puts result[:success] ? "✓ Sent for signature" : "✗ Error: #{result[:error]}"

# View signing URL
puts result[:signing_url]

# Open this URL in browser to test signature

# Check trade state
trade.reload
puts trade.state  # Should be "awaiting_seller_signature"
```

**Option B: Add Minimal UI (Quick)**
Just add one button to test:

```erb
<!-- In app/views/trades/show.html.erb, around line 219 -->
<%= button_to "🔐 Send for Digital Signature (NEW)",
              send_for_signature_trade_path(@trade),
              method: :post,
              class: "btn-app-primary mt-2" %>
```

---

## Priority Actions

### To Test DocuSeal Integration TODAY:
1. ✅ Backend is complete
2. ⚠️ Need DocuSeal credentials configured
3. ⚠️ Need DocuSeal template created
4. ❌ Need minimal UI (add 1 button)
5. ❌ Need DocuSeal embed partial

### Estimated Time to Test:
- Add one test button: 2 minutes
- Create DocuSeal embed partial: 15 minutes
- Configure DocuSeal account: 30 minutes
- Create template: 30 minutes
- **Total: ~1.5 hours to first test**

---

## Recommendation

**Fastest path to testing:**

1. Add the "Send for Digital Signature" button (2 min)
2. Create the DocuSeal embed partial (15 min)
3. Add signature state handling to view (15 min)
4. Configure DocuSeal credentials (see DOCUSEAL_SETUP.md)
5. Test!

Want me to implement the minimal UI changes now so you can test?
