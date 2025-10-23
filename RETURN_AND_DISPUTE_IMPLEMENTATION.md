# Return Refund & Dispute Management Implementation Plan

## 1. Return Acceptance - Refund Processing

### Current State
- When seller accepts return (`accept_return`), trade transitions to `returned` state
- `refund` event exists but lacks implementation
- Escrow record holds the original payment details

### Implementation Tasks

#### A. Add Refund to StripeService
**File:** `app/services/stripe_service.rb`

```ruby
def create_refund(trade)
  escrow = trade.escrow

  unless escrow&.payment_intent_id
    return { success: false, error: "No payment intent found for refund" }
  end

  # Refund the full amount (buyer paid price + fees)
  amount_to_refund = escrow.amount_cents

  begin
    refund = Stripe::Refund.create(
      payment_intent: escrow.payment_intent_id,
      amount: amount_to_refund,
      reason: 'requested_by_customer',
      metadata: {
        trade_id: trade.id,
        buyer_id: trade.buyer_id,
        seller_id: trade.seller_id
      }
    )

    # Update escrow status
    escrow.update!(
      status: 'refunded',
      refunded_at: Time.current
    )

    { success: true, refund: refund }
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe refund error: #{e.message}"
    { success: false, error: e.message }
  end
end
```

**Notes:**
- Refunds go back to original payment method
- Stripe automatically handles refund timing (5-10 business days)
- Platform fees are returned to platform automatically
- Webhook `charge.refunded` confirms completion

#### B. Wire Up Refund Trigger
**File:** `app/models/trade.rb`

Currently `process_refund` calls `StripeService.create_refund(self)` but needs error handling:

```ruby
def process_refund
  result = StripeService.create_refund(self)
  unless result[:success]
    Rails.logger.error "Refund failed for trade #{id}: #{result[:error]}"
    # Don't raise - allow manual retry
    return
  end

  Rails.logger.info "Refund processed: #{result[:refund].id}"
end
```

**State Machine:**
- `returned` → `refund` event → `refunded` state (with `after: :process_refund`)
- Already configured, just needs StripeService method

#### C. Add Refund Webhook Handler
**File:** `app/controllers/webhooks/stripe_controller.rb`

Add to event routing:
```ruby
when "charge.refunded"
  handle_charge_refunded(event.data.object)
```

Handler method:
```ruby
def handle_charge_refunded(charge)
  trade_id = charge.metadata.trade_id
  trade = Trade.find_by(id: trade_id)

  # Update escrow to refunded status
  escrow = trade.escrow
  escrow.update!(status: 'refunded', refunded_at: Time.current)

  # Could trigger notification here
  Rails.logger.info "Refund confirmed for trade #{trade_id}"
end
```

---

## 2. Email Notifications

### Current State
- `NotificationService` exists as stub (logs only)
- No email infrastructure configured
- Jumpstart Pro includes ActionMailer setup

### Implementation Options

#### Option A: ActionMailer (Built-in)
**Pros:**
- Already available in Rails/Jumpstart Pro
- Full control over templates
- No additional dependencies

**Cons:**
- Must build all templates manually
- No transactional email tracking
- No built-in analytics

**Implementation:**
```bash
# Generate mailer
rails generate mailer TradeMailer

# Methods needed:
# - trade_funded(trade)
# - item_shipped(trade)
# - item_delivered(trade)
# - item_accepted(trade)
# - item_rejected(trade)
# - return_accepted(trade)
# - refund_processed(trade)
```

#### Option B: Noticed Gem (Already in Jumpstart Pro!)
**Pros:**
- Already installed in Jumpstart Pro
- Multi-channel (email, SMS, push, in-app)
- Database-backed notifications
- Easy to extend

**Cons:**
- Still need to write email templates
- Additional abstraction layer

**Implementation:**
```ruby
# Create notification classes
# app/notifications/trade_funded_notification.rb
class TradeFundedNotification < Noticed::Base
  deliver_by :database
  deliver_by :email, mailer: "TradeMailer"

  param :trade

  def message
    "Trade ##{params[:trade].id} has been funded"
  end

  def url
    trade_path(params[:trade])
  end
end

# Usage in NotificationService
def send_trade_funded(trade)
  TradeFundedNotification.with(trade: trade).deliver(trade.seller)
end
```

#### Option C: Transactional Email Service
**Options:**
- **Postmark** (recommended for transactional)
- **SendGrid**
- **Mailgun**
- **Resend** (new, developer-friendly)

**Pros:**
- Professional deliverability
- Email analytics
- Template management
- Bounce/complaint handling

**Cons:**
- Monthly cost (~$10-50)
- External dependency

**Jumpstart Pro already supports:**
- Postmark adapter
- Mailgun adapter
- Resend adapter

Configure in `config/environments/production.rb`

### Recommended Approach
**Use Noticed + ActionMailer + Postmark:**
1. Noticed for notification orchestration
2. ActionMailer for email rendering
3. Postmark for delivery (production)
4. Letter_opener for preview (development)

**Implementation Steps:**
```bash
# 1. Create notification classes (one per event)
rails generate noticed:notification TradeFunded
rails generate noticed:notification TradeRefunded

# 2. Create mailer views
# app/views/trade_mailer/trade_funded.html.erb
# app/views/trade_mailer/trade_refunded.html.erb

# 3. Update NotificationService to use Noticed
def send_trade_funded(trade)
  TradeFundedNotification.with(trade: trade).deliver_later(trade.seller)
end

# 4. Configure Postmark (production)
# Add to credentials:
# postmark_api_key: xxx
```

---

## 3. Dispute Management

### Current State
- States exist: `disputed`, `resolved_release`, `resolved_refund`, `resolved_split`
- Events exist: `open_dispute`, `resolve_with_release`, `resolve_with_refund`, `resolve_with_split`
- No UI or management interface

### Option A: Build Custom Dispute System
**Features Needed:**
1. Dispute model (already exists)
2. Evidence upload (already exists)
3. Admin dashboard for review
4. Communication thread
5. Resolution workflows
6. Appeals process

**Pros:**
- Full control
- Integrated with existing data model
- No external costs

**Cons:**
- Significant development time (2-3 weeks)
- Ongoing maintenance burden
- Need moderation expertise
- Legal considerations

**Estimated Effort:** 40-60 hours

---

### Option B: Third-Party Dispute Resolution Gems

#### 1. **ActiveAdmin + Custom Workflow** (Most Common)
```ruby
gem 'activeadmin'

# Create admin interface for disputes
# app/admin/disputes.rb
ActiveAdmin.register Dispute do
  actions :all, except: [:destroy]

  member_action :resolve_for_buyer, method: :post
  member_action :resolve_for_seller, method: :post
  member_action :resolve_split, method: :post

  # Custom dispute resolution UI
end
```

**Pros:**
- Clean admin interface
- Quick to set up
- Good for internal team use

**Cons:**
- Still custom code
- No built-in arbitration workflow
- Need to build communication

**Estimated Effort:** 15-20 hours

---

#### 2. **Stripe Disputes API** (If using Stripe)
```ruby
# Stripe has built-in dispute handling for chargebacks
# But NOT for marketplace/escrow disputes between parties
```

**Verdict:** Not applicable for buyer-seller disputes

---

#### 3. **Mediation Service Integration**
**Services:**
- **Modria** (now Tyler Technologies) - Enterprise ODR platform
- **Matterhorn** - Online dispute resolution
- **Fairshake** - Consumer arbitration

**Pros:**
- Professional mediators
- Legal compliance
- Proven processes

**Cons:**
- Very expensive ($1000s/month)
- Complex integration
- Overkill for marketplace

**Verdict:** Too heavy for this use case

---

### Option C: Hybrid Approach (Recommended)

**Use Jumpstart Pro's existing tools + lightweight custom:**

1. **ActiveAdmin for dispute dashboard** (already in Jumpstart Pro)
2. **ActionText for communication** (rich text editor built-in)
3. **ActiveStorage for evidence** (already handling files)
4. **Simple resolution workflow**

**Implementation:**
```ruby
# Add to dispute model
class Dispute < ApplicationRecord
  has_rich_text :buyer_statement
  has_rich_text :seller_statement
  has_rich_text :admin_notes
  has_rich_text :resolution_notes

  has_many :messages, dependent: :destroy

  enum status: {
    open: 0,
    under_review: 1,
    resolved: 2,
    appealed: 3
  }

  enum resolution: {
    pending: 0,
    buyer_wins: 1,      # Full refund
    seller_wins: 2,     # Release funds
    split: 3,           # Partial refund
    escalated: 4        # Manual intervention
  }
end

# Simple admin UI
# app/admin/disputes.rb
ActiveAdmin.register Dispute do
  filter :status
  filter :created_at

  show do
    panel "Trade Details" do
      attributes_table_for dispute.trade do
        row :id
        row :item_name
        row :price
        row :buyer
        row :seller
      end
    end

    panel "Dispute Details" do
      div do
        h3 "Buyer Statement"
        div dispute.buyer_statement.to_s.html_safe
      end

      div do
        h3 "Seller Statement"
        div dispute.seller_statement.to_s.html_safe
      end
    end

    panel "Evidence" do
      table_for dispute.trade.evidences do
        column :user
        column :description
        column :created_at
      end
    end

    panel "Resolution Actions" do
      div do
        button_to "Refund Buyer", resolve_buyer_admin_dispute_path(dispute),
                  method: :post, class: "button"
        button_to "Release to Seller", resolve_seller_admin_dispute_path(dispute),
                  method: :post, class: "button"
        button_to "Split 50/50", resolve_split_admin_dispute_path(dispute),
                  method: :post, class: "button"
      end
    end
  end

  member_action :resolve_buyer, method: :post do
    trade = resource.trade
    if trade.may_resolve_with_refund?
      trade.resolve_with_refund!
      redirect_to admin_dispute_path(resource), notice: "Resolved in favor of buyer"
    end
  end

  member_action :resolve_seller, method: :post do
    trade = resource.trade
    if trade.may_resolve_with_release?
      trade.resolve_with_release!
      redirect_to admin_dispute_path(resource), notice: "Resolved in favor of seller"
    end
  end

  member_action :resolve_split, method: :post do
    trade = resource.trade
    if trade.may_resolve_with_split?
      trade.resolve_with_split!
      redirect_to admin_dispute_path(resource), notice: "Resolved with split"
    end
  end
end
```

**Estimated Effort:** 10-15 hours

---

## 4. Implementation Phases

### Phase 1: Refund Processing (High Priority)
**Time Estimate:** 4-6 hours

1. Add `StripeService.create_refund` method
2. Wire up `process_refund` callback
3. Add `charge.refunded` webhook handler
4. Test full refund flow
5. Update UI to show refund status

**Deliverable:** Buyers automatically receive refunds when sellers accept returns

---

### Phase 2: Email Notifications (High Priority)
**Time Estimate:** 8-12 hours

1. Choose approach (recommend Noticed + ActionMailer)
2. Create notification classes for key events:
   - Trade funded
   - Item shipped
   - Item delivered
   - Item accepted (payout initiated)
   - Item rejected (return initiated)
   - Return accepted (refund initiated)
   - Refund processed
3. Create email templates
4. Update NotificationService to trigger notifications
5. Configure email delivery (Postmark for production)
6. Test email flow

**Deliverable:** Both parties receive email updates at each stage

---

### Phase 3: Basic Dispute Management (Medium Priority)
**Time Estimate:** 10-15 hours

1. Add ActiveAdmin interface for disputes
2. Create dispute detail view with evidence
3. Add resolution action buttons
4. Implement resolution handlers:
   - `resolve_with_refund` → Full refund to buyer
   - `resolve_with_release` → Release funds to seller
   - `resolve_with_split` → Partial refund (50/50 or custom)
5. Add email notifications for dispute events
6. Create buyer/seller dispute view (read-only)

**Deliverable:** Admin can review and resolve disputes

---

### Phase 4: Enhanced Dispute Features (Low Priority)
**Time Estimate:** 15-20 hours

1. Add dispute communication thread
2. Allow parties to upload additional evidence
3. Add dispute escalation workflow
4. Create dispute analytics dashboard
5. Add automated dispute prevention (flag suspicious patterns)
6. Add dispute resolution templates

**Deliverable:** Full-featured dispute management system

---

## Summary: Recommended Next Steps

### Immediate (This Week)
1. ✅ **Refund Processing** - 4-6 hours
   - Critical for completing return workflow
   - Relatively simple implementation

2. ✅ **Basic Email Notifications** - 8-12 hours
   - Use Noticed + ActionMailer
   - Focus on key events (funded, shipped, delivered, accepted, refunded)
   - Configure Postmark for production

### Near Term (Next 1-2 Weeks)
3. ✅ **Basic Dispute Dashboard** - 10-15 hours
   - ActiveAdmin interface
   - Manual resolution by admin
   - Email notifications for disputes

### Future Enhancements
4. ⏸️ **Advanced Dispute Features** - As needed
   - Communication threads
   - Automated workflows
   - Analytics

---

## Cost Breakdown

### Development Time
- **Phase 1 (Refunds):** 4-6 hours
- **Phase 2 (Emails):** 8-12 hours
- **Phase 3 (Disputes):** 10-15 hours
- **Total Initial:** 22-33 hours

### External Services (Optional)
- **Postmark:** $10-15/month (25k emails)
- **Dispute resolution service:** Not recommended (too expensive)

### Total Recommended Investment
- **Development:** ~25-30 hours
- **Monthly cost:** ~$10-15 (email only)

---

## Gems/Libraries Needed

```ruby
# Gemfile additions
gem 'noticed', '~> 2.0'           # Already in Jumpstart Pro
gem 'activeadmin'                  # Already in Jumpstart Pro
gem 'actiontext'                   # Already in Rails 8
gem 'letter_opener', group: :development  # Email preview
```

**All needed gems are already included in Jumpstart Pro!**

---

## Questions to Answer

1. **Email Service:** Use Postmark or stick with SMTP for now?
   - **Recommendation:** Postmark for production, letter_opener for dev

2. **Dispute Resolution:** How hands-on do you want to be?
   - **Recommendation:** Start with simple admin review, automate later

3. **Notification Preferences:** Email only, or add SMS/push later?
   - **Recommendation:** Email first, add channels later

4. **Refund Policy:** Automatic refund on return acceptance, or admin approval?
   - **Recommendation:** Automatic for accepted returns, manual for disputes

5. **Dispute Timeline:** SLA for resolution? Auto-escalation?
   - **Recommendation:** 7-day resolution target, manual escalation initially
