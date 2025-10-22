# DocuSeal Digital Signature Integration - Implementation Plan

**Project:** Nexlock (Rails Monolith)
**Source:** escrow_next (Next.js/Rails API)
**Started:** 2025-10-22
**Status:** Planning Complete - Ready for Implementation

---

## Overview

Port the fully-functional DocuSeal integration from `escrow_next` (Next.js/Rails API) to `nexlock` (Rails monolith). The nexlock app already has the complete database schema and state machine in place, but is missing the entire service layer implementation.

**Key Architecture Decision:** The signature workflow will be the PRIMARY flow for trades, replacing the simple "send_to_buyer" → "agree" pattern with a legally-binding sequential signature process (Seller signs → Buyer signs).

---

## Current State Assessment

### ✅ Already Implemented in Nexlock
1. **Complete database schema** with all signature fields
   - `trades` table: signature timestamps, locked_for_editing flag
   - `trade_documents` table: DocuSeal submission tracking
   - `document_signatures` table: Individual signer records
2. **State machine** with all signature states and transitions
   - States: `awaiting_seller_signature`, `awaiting_buyer_signature`, `signature_deadline_missed`
   - Events: `send_for_signature!`, `seller_signs!`, `buyer_signs!`, etc.
3. **Trade model callbacks** for signature lifecycle
4. **Edit locking mechanism** during signature process
5. **Active Storage configured** with Digital Ocean Spaces
6. **DocuSeal redirect host** whitelisted in `config/initializers/allowed_redirect_hosts.rb`
7. **Badge variants** in helpers for signature states

### ❌ Missing Components
1. **TradeDocumentService** - Core service layer (100% missing)
2. **DocuSeal API integration** - HTTP client, authentication
3. **Webhook endpoint** for DocuSeal callbacks
4. **Controller actions** for signature workflow
5. **Routes** for signature actions and webhooks
6. **UI components** for signature states
7. **Background job** for deadline expiration
8. **Email notifications** for signature requests
9. **DocuSeal template** creation in their dashboard
10. **Configuration loading** from Rails credentials
11. **`signed_agreement_url` method** on Trade model

---

## Implementation Plan

### Phase 1: Foundation & Configuration (2-3 hours)

#### 1.1 Rails Credentials Configuration
Add DocuSeal configuration to `config/credentials/development.yml.enc` and `config/credentials/production.yml.enc`:

```yaml
docuseal:
  api_key: your_api_key_here
  api_url: https://api.docuseal.com
  webhook_secret: your_webhook_secret_here
  trade_agreement_template_id: your_template_id_here
```

Edit credentials:
```bash
# Development
EDITOR="code --wait" rails credentials:edit --environment development

# Production
EDITOR="code --wait" rails credentials:edit --environment production
```

**Note:** Following existing pattern from Digital Ocean Spaces configuration in `config/storage.yml`.

#### 1.2 DocuSeal Initializer
Create `config/initializers/docuseal.rb`:

```ruby
# Load DocuSeal configuration from Rails credentials
Rails.application.config.x.docuseal = OpenStruct.new(
  api_key: Rails.application.credentials.dig(:docuseal, :api_key),
  api_url: Rails.application.credentials.dig(:docuseal, :api_url) || 'https://api.docuseal.com',
  webhook_secret: Rails.application.credentials.dig(:docuseal, :webhook_secret),
  trade_agreement_template_id: Rails.application.credentials.dig(:docuseal, :trade_agreement_template_id)
)

# Validation checks (warn in development, raise in production)
Rails.application.config.after_initialize do
  config = Rails.application.config.x.docuseal

  missing = []
  missing << "api_key" if config.api_key.blank?
  missing << "trade_agreement_template_id" if config.trade_agreement_template_id.blank?
  missing << "webhook_secret" if config.webhook_secret.blank? && Rails.env.production?

  if missing.any?
    message = "DocuSeal configuration missing: #{missing.join(', ')}"
    if Rails.env.production?
      raise message
    else
      Rails.logger.warn "⚠️  #{message}"
    end
  else
    Rails.logger.info "✓ DocuSeal configured successfully"
    Rails.logger.info "  - API URL: #{config.api_url}"
    Rails.logger.info "  - Template ID: #{config.trade_agreement_template_id}"
    Rails.logger.info "  - Webhook secret: #{config.webhook_secret.present? ? 'configured' : 'not configured'}"
  end
end
```

Access pattern throughout the app:
```ruby
Rails.application.config.x.docuseal.api_key
Rails.application.config.x.docuseal.trade_agreement_template_id
```

#### 1.3 Dependencies
Add to `Gemfile`:
```ruby
gem "faraday", "~> 2.7"  # HTTP client for DocuSeal API
```

Run:
```bash
bundle install
```

#### 1.4 Active Storage Verification
**Status:** ✅ Already configured with Digital Ocean Spaces

Verify `config/storage.yml` has:
```yaml
digitalocean_spaces:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:digitalocean_spaces, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:digitalocean_spaces, :secret_access_key) %>
  region: us-east-1
  endpoint: 'https://nyc3.digitaloceanspaces.com'
  bucket: dev-nexlock
```

---

### Phase 2: Service Layer Implementation (8-10 hours)

#### 2.1 DocusealService (`app/services/docuseal_service.rb`)
**Purpose:** Direct API client for DocuSeal REST API

**File:** Port from `/Users/briancarpenter/development/escrow_next/backend/app/services/docuseal_service.rb`

**Key Methods:**
- `create_submission(trade:)` - POST to DocuSeal API with template merge fields
- `get_embedded_signing_url(submitter_id)` - Get iframe URL for signer
- `get_submission_status(submission_id)` - Poll submission status
- `download_signed_document(submission_id)` - Download completed PDF
- `cancel_submission(submission_id)` - Void incomplete submissions
- `build_merge_fields(trade)` - Populate template with 22+ trade data fields

**Configuration Access:**
```ruby
BASE_URL = Rails.application.config.x.docuseal.api_url
API_KEY = Rails.application.config.x.docuseal.api_key
```

**Merge Fields (22 fields):**
- Party info: seller_name, seller_email, seller_address, buyer_name, buyer_email, buyer_address
- Item details: item_name, item_description, item_category, item_condition
- Financial: price, currency, platform_fee, fee_split
- Terms: inspection_window, trade_id, created_date
- Addresses: buyer_city, buyer_state, buyer_zip, seller_city, seller_state, seller_zip

#### 2.2 TradeDocumentService (`app/services/trade_document_service.rb`)
**Purpose:** Orchestrates document lifecycle from creation to completion

**File:** Create new service (reference escrow_next implementation)

**Key Methods:**

**`create_trade_agreement(trade)`**
- Creates `TradeDocument` record with status: 'pending'
- Calls `DocusealService.create_submission(trade)`
- Creates 2 `DocumentSignature` records (seller role=0, buyer role=1)
- Stores `docuseal_submission_id`, `docuseal_submitter_id`, `docuseal_slug` for each signer
- Sets `signature_deadline_at` on trade (default: 7 days = 168 hours)
- Returns `{ success: true, trade_document: doc, signing_url: seller_url }` or error

**`process_signature_completion(trade_document, webhook_data)`**
- Finds `DocumentSignature` by `docuseal_submitter_id` from webhook
- Updates signature record:
  - `signed_at = webhook_data[:completed_at]`
  - `ip_address = webhook_data[:ip]`
  - `user_agent = webhook_data[:user_agent]`
  - `signature_metadata = webhook_data` (full payload as jsonb)
- Determines signer role (seller or buyer)
- Triggers state transition:
  - If seller signed → `trade.seller_signs!`
  - If buyer signed → `trade.buyer_signs!`
- If buyer just signed → calls `finalize_trade_document(trade_document)`

**`finalize_trade_document(trade_document)`**
- Downloads signed PDF from DocuSeal API
- Attaches to trade using Active Storage:
  ```ruby
  trade.signed_agreement.attach(
    io: StringIO.new(pdf_data),
    filename: "trade_agreement_#{trade.id}.pdf",
    content_type: 'application/pdf'
  )
  ```
- Updates `trade_document`:
  - `status = 'completed'`
  - `signed_document_url = trade.signed_agreement.url`
  - `completed_at = Time.current`
- Returns `{ success: true }`

**`check_signature_deadlines`** (Background job helper)
- Queries trades in signature states past deadline:
  ```ruby
  Trade.where(state: [:awaiting_seller_signature, :awaiting_buyer_signature])
       .where("signature_deadline_at < ?", Time.current)
  ```
- Calls `trade.signature_deadline_expired!` on each

#### 2.3 Update TradeService (`app/services/trade_service.rb`)
Add signature workflow methods to existing service:

**`send_for_signature(trade, deadline_hours: 168)`**
```ruby
def self.send_for_signature(trade, deadline_hours: 168)
  return { success: false, error: "Trade cannot be sent for signature" } unless trade.may_send_for_signature?

  trade.signature_deadline_at = deadline_hours.hours.from_now
  trade.signature_sent_at = Time.current
  trade.send_for_signature!  # State transition with callbacks

  # Get seller's signing URL immediately for return
  doc = trade.trade_documents.pending_status.last
  seller_sig = doc.document_signatures.seller_role.first
  url_result = DocusealService.get_embedded_signing_url(seller_sig.docuseal_submitter_id)

  { success: true, trade: trade, signing_url: url_result[:url] }
rescue => e
  { success: false, error: e.message }
end
```

**`cancel_signature_request(trade)`**
```ruby
def self.cancel_signature_request(trade)
  return { success: false, error: "Cannot cancel" } unless trade.may_cancel_signature_request?

  trade.cancel_signature_request!  # State transition handles cleanup
  { success: true, message: "Signature request cancelled" }
rescue => e
  { success: false, error: e.message }
end
```

**`get_signing_url(trade, user)`**
```ruby
def self.get_signing_url(trade, user)
  doc = trade.trade_documents.pending_status.last
  return { signed: false, error: "No pending document" } unless doc

  # Determine user's role
  role = (user.id == trade.seller_id) ? 'seller' : 'buyer'
  signature = doc.document_signatures.public_send("#{role}_role").first

  return { signed: true, message: "You have already signed" } if signature.signed_at.present?

  result = DocusealService.get_embedded_signing_url(signature.docuseal_submitter_id)
  { signed: false, slug: signature.docuseal_slug, url: result[:url] }
end
```

---

### Phase 3: Controllers & Routes (4-5 hours)

#### 3.1 TradesController Updates
**File:** `app/controllers/trades_controller.rb`

Add to `before_action :set_trade` list:
```ruby
before_action :set_trade, only: [..., :send_for_signature, :cancel_signature_request, :retry_signature, :signing_url]
```

**New Actions:**

**`send_for_signature`**
```ruby
def send_for_signature
  unless current_user == @trade.seller
    redirect_to trade_path(@trade), alert: "Only the seller can send for signature"
    return
  end

  result = TradeService.send_for_signature(@trade)

  if result[:success]
    redirect_to trade_path(@trade), notice: "Trade sent for signature"
  else
    redirect_to trade_path(@trade), alert: result[:error]
  end
end
```

**`cancel_signature_request`**
```ruby
def cancel_signature_request
  unless current_user == @trade.seller
    redirect_to trade_path(@trade), alert: "Only the seller can cancel"
    return
  end

  result = TradeService.cancel_signature_request(@trade)

  if result[:success]
    redirect_to trade_path(@trade), notice: result[:message]
  else
    redirect_to trade_path(@trade), alert: result[:error]
  end
end
```

**`retry_signature`**
```ruby
def retry_signature
  unless current_user == @trade.seller
    redirect_to trade_path(@trade), alert: "Only the seller can retry"
    return
  end

  if @trade.may_restart_signature_process?
    @trade.restart_signature_process!
    redirect_to trade_path(@trade), notice: "Trade returned to draft. You can now send for signature again."
  else
    redirect_to trade_path(@trade), alert: "Cannot retry signature"
  end
end
```

**`signing_url`** (AJAX endpoint for UI)
```ruby
def signing_url
  result = TradeService.get_signing_url(@trade, current_user)
  render json: result
end
```

#### 3.2 TradeDocumentsController (New)
**File:** `app/controllers/trade_documents_controller.rb`

```ruby
class TradeDocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trade
  before_action :set_trade_document, only: [:show, :download]
  before_action :authorize_access!

  def index
    @trade_documents = @trade.trade_documents
                             .includes(:document_signatures)
                             .order(created_at: :desc)
  end

  def show
    # Show document details with signature status
  end

  def download
    if @trade_document.signed_document_url.present?
      redirect_to @trade_document.signed_document_url, allow_other_host: true
    else
      redirect_to trade_path(@trade), alert: "Signed document not available yet"
    end
  end

  private

  def set_trade
    @trade = current_account.trades.find(params[:trade_id])
  end

  def set_trade_document
    @trade_document = @trade.trade_documents.find(params[:id])
  end

  def authorize_access!
    unless @trade.buyer_id == current_user.id || @trade.seller_id == current_user.id
      redirect_to root_path, alert: "Access denied"
    end
  end
end
```

#### 3.3 Webhooks::DocusealController (New)
**File:** `app/controllers/webhooks/docuseal_controller.rb`

```ruby
class Webhooks::DocusealController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_webhook_signature

  def create
    event_type = params[:event_type]

    case event_type
    when 'submitter.signed', 'form.completed'
      handle_signature_completion
    when 'submission.completed'
      handle_submission_completed
    when 'submission.expired', 'form.expired'
      handle_submission_expired
    else
      Rails.logger.info "Unhandled DocuSeal webhook event: #{event_type}"
    end

    head :ok
  rescue => e
    Rails.logger.error "DocuSeal webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :unprocessable_entity
  end

  private

  def handle_signature_completion
    submission_id = params.dig(:data, :submission_id).to_s
    trade_document = TradeDocument.find_by(docuseal_submission_id: submission_id)

    unless trade_document
      Rails.logger.error "TradeDocument not found for submission_id: #{submission_id}"
      return
    end

    result = TradeDocumentService.process_signature_completion(trade_document, params[:data])

    unless result[:success]
      Rails.logger.error "Failed to process signature: #{result[:error]}"
    end
  end

  def handle_submission_completed
    # Similar to signature completion - ensures document is finalized
    handle_signature_completion
  end

  def handle_submission_expired
    submission_id = params.dig(:data, :id).to_s
    trade_document = TradeDocument.find_by(docuseal_submission_id: submission_id)

    if trade_document && trade_document.trade.may_signature_deadline_expired?
      trade_document.trade.signature_deadline_expired!
    end
  end

  def verify_webhook_signature
    webhook_secret = Rails.application.config.x.docuseal.webhook_secret

    # Allow in development without secret
    return true if Rails.env.development? && webhook_secret.blank?

    provided_signature = request.headers['X-Docuseal-Signature']

    if webhook_secret.blank?
      Rails.logger.warn "DocuSeal webhook secret not configured"
      return true if Rails.env.development?
      head :unauthorized
      return false
    end

    expected_signature = OpenSSL::HMAC.hexdigest(
      'SHA256',
      webhook_secret,
      request.raw_post
    )

    unless ActiveSupport::SecurityUtils.secure_compare(
      provided_signature.to_s,
      expected_signature
    )
      Rails.logger.error "DocuSeal webhook signature verification failed"
      head :unauthorized
      return false
    end

    true
  end
end
```

#### 3.4 Routes Configuration
**File:** `config/routes/trades.rb`

```ruby
resources :trades, only: [:index, :new, :create, :show] do
  member do
    post :attach_media
    post :send_to_buyer              # Existing simple flow
    post :agree                       # Existing simple flow
    post :send_for_signature          # NEW: DocuSeal flow
    post :cancel_signature_request    # NEW
    post :retry_signature             # NEW
    get :signing_url                  # NEW: AJAX endpoint
    post :ship
    post :mark_delivered
    post :confirm_receipt
    post :accept
    post :reject
  end

  resources :trade_documents, only: [:index, :show] do
    member do
      get :download
    end
  end
end
```

**File:** `config/routes/webhooks.rb`

```ruby
scope :webhooks, module: :webhooks do
  post :stripe, to: "stripe#create"
  post :docuseal, to: "docuseal#create"  # NEW
end
```

---

### Phase 4: Background Jobs (2-3 hours)

#### 4.1 Signature Deadline Check Job
**File:** `app/jobs/signature_deadline_check_job.rb`

```ruby
class SignatureDeadlineCheckJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Running signature deadline check..."

    result = TradeDocumentService.check_signature_deadlines

    if result[:expired_count] > 0
      Rails.logger.info "Expired #{result[:expired_count]} signature request(s)"
    end
  end
end
```

#### 4.2 Cron Configuration
**File:** `config/recurring.yml` (if using Solid Queue recurring jobs)

```yaml
signature_deadline_check:
  class: SignatureDeadlineCheckJob
  schedule: every hour
```

Or use whenever gem / cron:
```ruby
# config/schedule.rb
every 1.hour do
  runner "SignatureDeadlineCheckJob.perform_later"
end
```

#### 4.3 Optional: Polling Fallback Job
**File:** `app/jobs/docuseal_submission_poll_job.rb`

Only if webhooks prove unreliable - creates polling backup:
```ruby
class DocusealSubmissionPollJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 10

  def perform(trade_document_id)
    doc = TradeDocument.find(trade_document_id)
    return if doc.completed_status? || doc.expired_status?

    result = DocusealService.get_submission_status(doc.docuseal_submission_id)

    if result[:success]
      # Check each submitter and process any new signatures
      # Reschedule if still pending
      self.class.set(wait: 5.minutes).perform_later(trade_document_id) if doc.pending_status?
    end
  end
end
```

---

### Phase 5: View Layer (4-6 hours)

#### 5.1 Trade Show Page Updates
**File:** `app/views/trades/show.html.erb`

Add signature state handling in the main content area:

```erb
<%# Signature States %>
<% if @trade.awaiting_seller_signature? || @trade.awaiting_buyer_signature? %>
  <div class="app-card mb-6">
    <h2 class="text-lg font-semibold mb-4">
      <%= @trade.awaiting_seller_signature? ? "Seller Signature Required" : "Buyer Signature Required" %>
    </h2>

    <% if @is_seller && @trade.awaiting_seller_signature? %>
      <%# Seller needs to sign %>
      <p class="text-sm text-app-muted mb-4">Please review and sign the trade agreement below.</p>
      <div id="docuseal-container">
        <%= render "trades/docuseal_signature_form", trade: @trade %>
      </div>
    <% elsif @is_buyer && @trade.awaiting_buyer_signature? %>
      <%# Buyer needs to sign %>
      <p class="text-sm text-app-muted mb-4">Please review and sign the trade agreement below.</p>
      <div id="docuseal-container">
        <%= render "trades/docuseal_signature_form", trade: @trade %>
      </div>
    <% else %>
      <%# Waiting for other party %>
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

    <% if @is_seller && (@trade.awaiting_seller_signature? || @trade.awaiting_buyer_signature?) %>
      <div class="mt-4 pt-4 border-t border-app-subtle">
        <%= button_to "Cancel Signature Request",
                      cancel_signature_request_trade_path(@trade),
                      method: :post,
                      class: "btn-app-secondary",
                      data: { turbo_confirm: "Are you sure? This will return the trade to draft state." } %>
      </div>
    <% end %>

    <% if @trade.signature_deadline_at.present? %>
      <p class="mt-4 text-xs text-app-muted">
        Signature deadline: <%= l(@trade.signature_deadline_at, format: :long) %>
      </p>
    <% end %>
  </div>
<% end %>

<%# Signature Deadline Missed %>
<% if @trade.signature_deadline_missed? %>
  <div class="app-card app-card-outline border-app-strong bg-[color:var(--app-danger-soft-bg)] text-app-danger mb-6">
    <h2 class="text-lg font-semibold mb-2">Signature Deadline Missed</h2>
    <p class="text-sm mb-4">The signature request has expired. You can retry the signature process if you'd like to proceed.</p>

    <% if @is_seller %>
      <%= button_to "Retry Signature Process",
                    retry_signature_trade_path(@trade),
                    method: :post,
                    class: "btn-app-primary" %>
    <% else %>
      <p class="text-sm text-app-muted">Waiting for seller to restart the signature process.</p>
    <% end %>
  </div>
<% end %>

<%# Draft State - Send for Signature %>
<% if @trade.draft? && @is_seller %>
  <div class="app-card mb-6">
    <h2 class="text-lg font-semibold mb-4">Ready to Send for Signature</h2>
    <p class="text-sm text-app-muted mb-4">
      Once sent, you and the buyer will be asked to digitally sign a legally binding trade agreement.
      The trade will be locked for editing during the signature process.
    </p>

    <%= button_to "Send for Signature",
                  send_for_signature_trade_path(@trade),
                  method: :post,
                  class: "btn-app-primary",
                  data: { turbo_confirm: "Send this trade for digital signature? You'll be asked to sign first, then the buyer." } %>
  </div>
<% end %>

<%# Awaiting Funding - Show Signed Agreement %>
<% if @trade.awaiting_funding? || @trade.funded? || @trade.shipped? %>
  <% signed_doc = @trade.trade_documents.completed_status.trade_agreement_type.last %>
  <% if signed_doc&.signed_document_url.present? %>
    <div class="app-card mb-6">
      <h3 class="text-base font-semibold mb-2">Signed Trade Agreement</h3>
      <p class="text-sm text-app-muted mb-3">Both parties have signed the agreement.</p>
      <%= link_to "Download Signed Agreement (PDF)",
                  download_trade_trade_document_path(@trade, signed_doc),
                  target: "_blank",
                  class: "btn-app-secondary inline-flex items-center gap-2" %>

      <div class="mt-4 pt-4 border-t border-app-subtle">
        <p class="text-xs text-app-muted mb-2">Signatures:</p>
        <% signed_doc.document_signatures.each do |sig| %>
          <div class="flex items-center gap-2 text-xs">
            <span class="inline-flex items-center px-2 py-1 rounded-full bg-app-subtle">
              <%= sig.signer_role.titleize %>
            </span>
            <span class="text-app-muted"><%= sig.signer_email %></span>
            <span class="text-app-muted">• Signed <%= l(sig.signed_at, format: :short) %></span>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>
<% end %>
```

#### 5.2 DocuSeal Embed Partial
**File:** `app/views/trades/_docuseal_signature_form.html.erb`

```erb
<div id="docuseal-form-container" data-trade-id="<%= trade.id %>">
  <div id="docuseal-loading" class="text-center py-8">
    <svg class="animate-spin h-8 w-8 text-app-accent mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    <p class="mt-2 text-sm text-app-muted">Loading signature form...</p>
  </div>
  <div id="docuseal-form-wrapper" style="display: none;"></div>
</div>

<script src="https://cdn.docuseal.com/js/form.js" async></script>

<script>
document.addEventListener('DOMContentLoaded', function() {
  const tradeId = '<%= trade.id %>';
  const container = document.getElementById('docuseal-form-wrapper');
  const loading = document.getElementById('docuseal-loading');

  // Fetch signing URL from backend
  fetch(`/trades/${tradeId}/signing_url`, {
    headers: {
      'Accept': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    }
  })
  .then(response => response.json())
  .then(data => {
    if (data.signed) {
      // Already signed
      loading.innerHTML = `
        <div class="text-center py-8">
          <svg class="h-12 w-12 text-green-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <p class="mt-2 font-medium">You have already signed this document</p>
          <p class="mt-1 text-sm text-app-muted">${data.message || 'Waiting for other party'}</p>
        </div>
      `;
    } else if (data.slug) {
      // Load DocuSeal form
      loading.style.display = 'none';
      container.style.display = 'block';

      const form = document.createElement('docuseal-form');
      form.setAttribute('id', 'docusealForm');
      form.setAttribute('data-src', `https://docuseal.com/s/${data.slug}`);
      container.appendChild(form);

      // Listen for completion
      form.addEventListener('completed', function() {
        // Reload page to show updated state
        window.location.reload();
      });
    } else {
      loading.innerHTML = `
        <div class="text-center py-8 text-red-500">
          <p>Error loading signature form</p>
          <p class="text-sm">${data.error || 'Please try again'}</p>
        </div>
      `;
    }
  })
  .catch(error => {
    console.error('Error loading signing URL:', error);
    loading.innerHTML = `
      <div class="text-center py-8 text-red-500">
        <p>Error loading signature form</p>
        <p class="text-sm">Please refresh the page</p>
      </div>
    `;
  });
});
</script>
```

#### 5.3 Trade Documents Views (Optional)
**File:** `app/views/trade_documents/index.html.erb`

```erb
<% page_title = "Documents for Trade ##{@trade.id}" %>
<% Current.meta_tags.set(title: page_title) %>

<div class="space-y-8">
  <%= render PageHeaderComponent.new(title: page_title) do |header| %>
    <% header.actions do %>
      <%= link_to "Back to Trade", trade_path(@trade), class: "btn-app-secondary" %>
    <% end %>
  <% end %>

  <%= render CardComponent.new do %>
    <div class="space-y-4">
      <% @trade_documents.each do |doc| %>
        <div class="border border-app-subtle rounded-lg p-4">
          <div class="flex items-start justify-between">
            <div>
              <h3 class="font-semibold"><%= doc.title || doc.document_type.titleize %></h3>
              <p class="text-sm text-app-muted mt-1">
                Status: <%= render BadgeComponent.new(variant: doc.completed_status? ? :success : :warning) do %>
                  <%= doc.status.titleize %>
                <% end %>
              </p>
              <% if doc.completed_at %>
                <p class="text-xs text-app-muted mt-1">Completed: <%= l(doc.completed_at, format: :long) %></p>
              <% end %>
            </div>
            <% if doc.signed_document_url.present? %>
              <%= link_to "Download", download_trade_trade_document_path(@trade, doc),
                          target: "_blank", class: "btn-app-secondary" %>
            <% end %>
          </div>

          <% if doc.document_signatures.any? %>
            <div class="mt-4 pt-4 border-t border-app-subtle">
              <p class="text-xs font-medium text-app-muted mb-2">Signatures:</p>
              <div class="space-y-2">
                <% doc.document_signatures.each do |sig| %>
                  <div class="flex items-center gap-3 text-sm">
                    <%= render BadgeComponent.new(variant: sig.signed_at ? :success : :secondary) do %>
                      <%= sig.signer_role.titleize %>
                    <% end %>
                    <span><%= sig.signer_email %></span>
                    <% if sig.signed_at %>
                      <span class="text-app-muted">• <%= l(sig.signed_at, format: :short) %></span>
                    <% else %>
                      <span class="text-app-muted">• Pending</span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <% if @trade_documents.empty? %>
        <p class="text-center text-app-muted py-8">No documents yet</p>
      <% end %>
    </div>
  <% end %>
</div>
```

---

### Phase 6: Email Notifications (2-3 hours)

#### 6.1 Mailer Setup
**File:** `app/mailers/trade_mailer.rb`

```ruby
class TradeMailer < ApplicationMailer
  def signature_request_to_buyer(trade)
    @trade = trade
    @buyer_email = trade.buyer_email
    @seller = trade.seller
    @signing_url = "#{ENV['APP_URL']}/trades/#{trade.id}"

    mail(
      to: @buyer_email,
      subject: "Sign Trade Agreement for #{trade.item.name}"
    )
  end

  def signature_deadline_reminder(trade)
    @trade = trade
    @hours_remaining = ((trade.signature_deadline_at - Time.current) / 3600).round

    # Send to whoever hasn't signed yet
    recipient = if trade.awaiting_seller_signature?
      trade.seller.email
    elsif trade.awaiting_buyer_signature?
      trade.buyer_email
    end

    mail(
      to: recipient,
      subject: "Reminder: Sign Trade Agreement (#{@hours_remaining}h remaining)"
    )
  end

  def signature_deadline_missed(trade)
    @trade = trade

    mail(
      to: trade.seller.email,
      subject: "Trade Signature Deadline Missed - ##{trade.id}"
    )
  end

  def both_parties_signed(trade)
    @trade = trade

    recipients = [trade.seller.email, trade.buyer_email].compact

    mail(
      to: recipients,
      subject: "Trade Agreement Signed - Ready to Fund"
    )
  end
end
```

#### 6.2 Email Templates
Create corresponding views in `app/views/trade_mailer/`:
- `signature_request_to_buyer.html.erb`
- `signature_deadline_reminder.html.erb`
- `signature_deadline_missed.html.erb`
- `both_parties_signed.html.erb`

#### 6.3 Update Trade Model Callbacks
**File:** `app/models/trade.rb`

Replace stub methods:

```ruby
def notify_buyer_to_sign
  TradeMailer.signature_request_to_buyer(self).deliver_later
  Rails.logger.info "Trade #{id} - Buyer notification sent"
end

def notify_deadline_missed
  TradeMailer.signature_deadline_missed(self).deliver_later
  Rails.logger.info "Trade #{id} - Deadline missed notification sent"
end
```

Add new callback to `buyer_signs!` event:
```ruby
after do
  notify_both_parties_signed
end

def notify_both_parties_signed
  TradeMailer.both_parties_signed(self).deliver_later
  Rails.logger.info "Trade #{id} - Both parties signed notification sent"
end
```

---

### Phase 7: DocuSeal Template Setup (1-2 hours)

#### 7.1 Template Creation in DocuSeal Dashboard
1. Log into DocuSeal dashboard (https://docuseal.com)
2. Navigate to Templates
3. Click "Create Template"
4. Name: "Nexlock Trade Agreement"
5. Upload base PDF or create from scratch
6. Add 2 roles:
   - Role 1: "Seller" (signs first)
   - Role 2: "Buyer" (signs second)
7. Set signing order: Sequential (Seller → Buyer)

**Add merge fields (22 fields):**

**Party Information:**
- `{{seller_name}}` - Text
- `{{seller_email}}` - Text
- `{{seller_address}}` - Text
- `{{buyer_name}}` - Text
- `{{buyer_email}}` - Text
- `{{buyer_address}}` - Text

**Item Details:**
- `{{item_name}}` - Text
- `{{item_description}}` - Text
- `{{item_category}}` - Text
- `{{item_condition}}` - Text

**Financial Terms:**
- `{{price}}` - Text (formatted currency)
- `{{currency}}` - Text
- `{{platform_fee}}` - Text (formatted currency)
- `{{fee_split}}` - Text

**Trade Terms:**
- `{{inspection_window}}` - Text
- `{{trade_id}}` - Text
- `{{created_date}}` - Text

**Addresses (detailed):**
- `{{buyer_city}}` - Text
- `{{buyer_state}}` - Text
- `{{buyer_zip}}` - Text
- `{{seller_city}}` - Text
- `{{seller_state}}` - Text
- `{{seller_zip}}` - Text

**Interactive Fields:**
- Signature field for Seller (Role 1)
- Signature field for Buyer (Role 2)
- Date signed fields (auto-filled)

8. Save template and copy Template ID
9. Add Template ID to Rails credentials:
   ```bash
   EDITOR="code --wait" rails credentials:edit --environment development
   ```
   Add:
   ```yaml
   docuseal:
     trade_agreement_template_id: [paste_template_id_here]
   ```

#### 7.2 Webhook Configuration
1. In DocuSeal dashboard → Settings → Webhooks
2. Add webhook URL: `https://yourdomain.com/webhooks/docuseal`
3. Copy webhook secret
4. Add to Rails credentials:
   ```yaml
   docuseal:
     webhook_secret: [paste_secret_here]
   ```
5. Select events to send:
   - ✅ submitter.signed
   - ✅ form.completed
   - ✅ submission.completed
   - ✅ submission.expired

#### 7.3 Testing Script
**File:** `lib/tasks/docuseal_test.rake`

```ruby
namespace :docuseal do
  desc "Test DocuSeal integration with sample trade"
  task test: :environment do
    puts "Testing DocuSeal integration..."

    # Find or create test trade
    trade = Trade.draft.first || begin
      account = Account.first
      seller = account.users.first

      TradeService.create_trade(
        account: account,
        seller: seller,
        buyer_email: "test-buyer@example.com",
        item_params: {
          name: "Test Guitar",
          description: "Testing DocuSeal integration",
          category: "guitar",
          condition: "new"
        },
        trade_params: {
          price_cents: 5000,
          fee_split: "buyer",
          inspection_window_hours: 48,
          currency: "USD"
        }
      )[:trade]
    end

    puts "Using trade: #{trade.id}"

    # Test send for signature
    result = TradeService.send_for_signature(trade)

    if result[:success]
      puts "✓ Signature request created successfully"
      puts "  Signing URL: #{result[:signing_url]}"
      puts "  Visit: http://localhost:3000/trades/#{trade.id}"
    else
      puts "✗ Error: #{result[:error]}"
    end
  end
end
```

Run:
```bash
rails docuseal:test
```

---

### Phase 8: Helper & Utility Updates (1-2 hours)

#### 8.1 Trade Model Helper Methods
**File:** `app/models/trade.rb`

Add public methods:

```ruby
# Returns URL to signed PDF (via Active Storage)
def signed_agreement_url
  signed_agreement.attached? ? signed_agreement.url : trade_documents.completed_status.trade_agreement_type.last&.signed_document_url
end

# Returns boolean hash of signature progress
def signature_progress
  doc = trade_documents.pending_status.last || trade_documents.completed_status.last
  return { seller: false, buyer: false } unless doc

  {
    seller: doc.document_signatures.seller_role.first&.signed_at.present?,
    buyer: doc.document_signatures.buyer_role.first&.signed_at.present?
  }
end

# Check if signed agreement can be downloaded
def can_download_agreement?
  signed_agreement_url.present? && (awaiting_funding? || funded? || shipped? || delivered_pending_confirmation? || inspection? || accepted?)
end

# Get active signature document
def active_signature_document
  trade_documents.pending_status.trade_agreement_type.last
end
```

#### 8.2 Active Storage Association
**File:** `app/models/trade.rb`

Add association for signed PDF:

```ruby
has_one_attached :signed_agreement
```

#### 8.3 Policy Updates
**File:** `app/policies/trade_policy.rb`

Add policy methods:

```ruby
def send_for_signature?
  user.id == record.seller_id && record.draft?
end

def cancel_signature_request?
  user.id == record.seller_id && (record.awaiting_seller_signature? || record.awaiting_buyer_signature?)
end

def retry_signature?
  user.id == record.seller_id && record.signature_deadline_missed?
end

def view_signed_agreement?
  (user.id == record.seller_id || user.id == record.buyer_id) && record.can_download_agreement?
end
```

#### 8.4 Enum Fix for TradeDocument
**File:** `app/models/trade_document.rb`

Update enum syntax to Rails 8 format:

```ruby
enum :status, { draft: 0, pending: 1, completed: 2, expired: 3 }, suffix: true
enum :document_type, { trade_agreement: 0, shipping_label: 1, release_authorization: 2 }, suffix: true
```

---

### Phase 9: Testing & Integration (4-6 hours)

#### 9.1 Service Layer Tests
**File:** `test/services/docuseal_service_test.rb`

Use WebMock and VCR for API testing:

```ruby
require "test_helper"

class DocusealServiceTest < ActiveSupport::TestCase
  setup do
    @trade = trades(:one)
    @service = DocusealService
  end

  test "create_submission with valid trade" do
    VCR.use_cassette("docuseal_create_submission") do
      result = @service.create_submission(trade: @trade)

      assert result[:success]
      assert_not_nil result[:data]
      assert_equal 2, result[:data].length  # Seller and Buyer
    end
  end

  test "build_merge_fields includes all required fields" do
    fields = @service.send(:build_merge_fields, @trade)

    assert_includes fields.keys, :seller_name
    assert_includes fields.keys, :buyer_email
    assert_includes fields.keys, :item_name
    assert_includes fields.keys, :price
    assert_equal 22, fields.keys.length
  end
end
```

#### 9.2 Controller Tests
**File:** `test/controllers/trades_controller_test.rb`

```ruby
test "should send trade for signature as seller" do
  sign_in users(:seller)
  trade = trades(:draft_trade)

  assert trade.draft?

  post send_for_signature_trade_url(trade)

  assert_redirected_to trade_path(trade)
  assert_equal "Trade sent for signature", flash[:notice]

  trade.reload
  assert trade.awaiting_seller_signature?
  assert trade.locked_for_editing?
end

test "should not send for signature as buyer" do
  sign_in users(:buyer)
  trade = trades(:draft_trade)

  post send_for_signature_trade_url(trade)

  assert_redirected_to trade_path(trade)
  assert_match /only the seller/i, flash[:alert]
end
```

**File:** `test/controllers/webhooks/docuseal_controller_test.rb`

```ruby
require "test_helper"

class Webhooks::DocusealControllerTest < ActionDispatch::IntegrationTest
  setup do
    @trade_document = trade_documents(:pending_signature)
    @webhook_secret = Rails.application.config.x.docuseal.webhook_secret
  end

  test "should process submitter.signed webhook" do
    payload = {
      event_type: "submitter.signed",
      data: {
        submission_id: @trade_document.docuseal_submission_id,
        id: @trade_document.document_signatures.seller_role.first.docuseal_submitter_id,
        email: "seller@example.com",
        role: "Seller",
        status: "completed",
        completed_at: Time.current.iso8601,
        ip: "192.168.1.1",
        user_agent: "Test"
      }
    }.to_json

    signature = generate_webhook_signature(payload)

    post webhooks_docuseal_url,
         params: payload,
         headers: {
           "Content-Type" => "application/json",
           "X-Docuseal-Signature" => signature
         }

    assert_response :success

    # Verify signature was recorded
    sig = @trade_document.document_signatures.seller_role.first.reload
    assert_not_nil sig.signed_at
  end

  private

  def generate_webhook_signature(payload)
    OpenSSL::HMAC.hexdigest('SHA256', @webhook_secret, payload)
  end
end
```

#### 9.3 Integration Tests
**File:** `test/integration/signature_flow_test.rb`

```ruby
require "test_helper"

class SignatureFlowTest < ActionDispatch::IntegrationTest
  test "complete signature workflow" do
    seller = users(:seller)
    buyer = users(:buyer)

    # 1. Create trade
    sign_in seller
    post trades_url, params: {
      trade: {
        buyer_email: buyer.email,
        price_dollars: "50.00",
        fee_split: "buyer",
        inspection_window_hours: 48,
        item_attributes: {
          name: "Test Item",
          description: "Test",
          category: "guitar",
          condition: "new"
        }
      }
    }

    trade = Trade.last
    assert trade.draft?

    # 2. Send for signature
    post send_for_signature_trade_url(trade)
    trade.reload

    assert trade.awaiting_seller_signature?
    assert trade.locked_for_editing?
    assert_not_nil trade.signature_deadline_at

    # 3. Seller signs (simulate webhook)
    doc = trade.active_signature_document
    seller_sig = doc.document_signatures.seller_role.first

    TradeDocumentService.process_signature_completion(doc, {
      id: seller_sig.docuseal_submitter_id,
      completed_at: Time.current.iso8601,
      ip: "127.0.0.1",
      user_agent: "Test"
    })

    trade.reload
    assert trade.awaiting_buyer_signature?
    assert_not_nil trade.seller_signed_at

    # 4. Buyer signs (simulate webhook)
    buyer_sig = doc.document_signatures.buyer_role.first

    TradeDocumentService.process_signature_completion(doc, {
      id: buyer_sig.docuseal_submitter_id,
      completed_at: Time.current.iso8601,
      ip: "127.0.0.1",
      user_agent: "Test"
    })

    trade.reload
    assert trade.awaiting_funding?
    assert_not_nil trade.buyer_signed_at
    assert_not trade.locked_for_editing?

    # 5. Verify signed document
    doc.reload
    assert doc.completed_status?
    assert_not_nil doc.signed_document_url
  end
end
```

#### 9.4 Manual Testing Checklist

**Development Environment Testing:**
```
□ Rails credentials configured with DocuSeal keys
□ DocuSeal template created with correct merge fields
□ Webhook endpoint accessible (use ngrok for local testing)
□ Active Storage configured and tested

Trade Creation & Signature:
□ Create new trade in draft state
□ Click "Send for Signature" button
□ Seller signing iframe loads correctly
□ Complete seller signature in DocuSeal
□ Webhook processes seller signature
□ Trade transitions to awaiting_buyer_signature
□ Buyer signing iframe loads correctly
□ Complete buyer signature in DocuSeal
□ Webhook processes buyer signature
□ Trade transitions to awaiting_funding
□ Trade unlocks for editing (locked_for_editing = false)
□ Signed PDF downloads successfully

Error Cases:
□ Cancel signature request (seller only)
□ Trade locks during signature process
□ Deadline expiration triggers state change
□ Retry after deadline miss works
□ Non-party users cannot access signing URLs
□ Invalid webhook signatures rejected

Email Notifications:
□ Buyer receives signature request email
□ Deadline reminder emails sent
□ Both parties receive completion email
□ Deadline missed notification sent
```

---

### Phase 10: Migration & Deployment (2-3 hours)

#### 10.1 Data Migration
**File:** `lib/tasks/migrate_existing_trades.rake`

```ruby
namespace :trades do
  desc "Migrate existing trades to skip signature flow (legacy)"
  task migrate_legacy: :environment do
    puts "Migrating existing trades..."

    # Trades that have already been "agreed" should skip signature
    count = 0

    Trade.where(state: :awaiting_funding).find_each do |trade|
      # Mark as legacy - no signature document required
      unless trade.trade_documents.any?
        trade.update_columns(
          seller_signed_at: trade.created_at,
          buyer_agreed_at: trade.created_at,
          locked_for_editing: false
        )
        count += 1
      end
    end

    puts "✓ Migrated #{count} legacy trades"
  end
end
```

#### 10.2 Documentation Updates
**File:** `README.md`

Add section:

```markdown
## DocuSeal Digital Signatures

This application uses DocuSeal for legally binding digital signatures on trade agreements.

### Setup

1. Create a DocuSeal account at https://docuseal.com
2. Create a trade agreement template with 22 merge fields (see docs/DOCUSEAL_TEMPLATE_SPECIFICATION.md)
3. Configure webhook endpoint in DocuSeal dashboard
4. Add credentials to Rails encrypted credentials:

```bash
EDITOR="code --wait" rails credentials:edit --environment production
```

```yaml
docuseal:
  api_key: your_api_key
  api_url: https://api.docuseal.com
  webhook_secret: your_webhook_secret
  trade_agreement_template_id: your_template_id
```

### Workflow

1. Seller creates trade → Draft state
2. Seller clicks "Send for Signature"
3. Trade locks for editing
4. Seller signs via embedded DocuSeal iframe
5. Buyer signs via embedded DocuSeal iframe
6. Signed PDF stored in Digital Ocean Spaces
7. Trade unlocks → Awaiting Funding

### Webhook Endpoint

```
POST /webhooks/docuseal
```

Events handled:
- `submitter.signed` - Individual signs
- `submission.completed` - All parties signed
- `submission.expired` - Deadline missed

### Testing

```bash
# Test DocuSeal integration
rails docuseal:test

# Run full test suite
rails test

# Integration test
rails test test/integration/signature_flow_test.rb
```
```

#### 10.3 Deployment Checklist
**File:** `docs/DOCUSEAL_DEPLOYMENT_CHECKLIST.md`

```markdown
# DocuSeal Integration - Deployment Checklist

## Pre-Deployment

### DocuSeal Configuration
- [ ] Create production DocuSeal account
- [ ] Create trade agreement template
- [ ] Note template ID
- [ ] Configure webhook URL: `https://yourdomain.com/webhooks/docuseal`
- [ ] Copy webhook secret
- [ ] Test template with sample data

### Rails Configuration
- [ ] Add DocuSeal credentials to production credentials file:
  ```bash
  EDITOR="code --wait" rails credentials:edit --environment production
  ```
- [ ] Verify Digital Ocean Spaces credentials configured
- [ ] Verify Active Storage configured for production
- [ ] Set APP_URL environment variable (for email links)

### Code Deployment
- [ ] Deploy code to production
- [ ] Run migrations (schema already up to date)
- [ ] Run legacy trade migration:
  ```bash
  rails trades:migrate_legacy RAILS_ENV=production
  ```
- [ ] Restart application server
- [ ] Verify DocuSeal initializer loads without errors:
  ```bash
  rails runner "puts Rails.application.config.x.docuseal.api_key.present? ? '✓' : '✗'"
  ```

## Post-Deployment

### Testing
- [ ] Create test trade in production
- [ ] Send for signature
- [ ] Complete seller signature
- [ ] Verify webhook processes correctly
- [ ] Complete buyer signature
- [ ] Verify trade transitions to awaiting_funding
- [ ] Download signed PDF
- [ ] Verify PDF stored in Digital Ocean Spaces
- [ ] Test email notifications delivered
- [ ] Test deadline expiration (optional: manually update signature_deadline_at)
- [ ] Test cancellation flow

### Monitoring
- [ ] Monitor webhook delivery in DocuSeal dashboard
- [ ] Check Rails logs for DocuSeal API errors
- [ ] Monitor background job queue for deadline checks
- [ ] Set up alerts for failed webhooks
- [ ] Monitor Active Storage for failed uploads

### Documentation
- [ ] Update user documentation with signature workflow
- [ ] Train customer support on signature process
- [ ] Document troubleshooting steps
- [ ] Update FAQ with signature questions

## Rollback Plan

If issues occur:

1. **Disable signature flow temporarily:**
   - Comment out "Send for Signature" button in view
   - Keep old "Send to Buyer" → "Agree" flow active

2. **Fix webhook issues:**
   - Verify webhook secret matches
   - Check webhook URL is accessible
   - Review webhook logs in DocuSeal dashboard

3. **Database rollback not needed:**
   - Schema changes are additive only
   - Old flow still works with existing tables

## Support Contacts

- DocuSeal Support: support@docuseal.com
- DocuSeal Docs: https://docs.docuseal.com
- Webhook Troubleshooting: https://docs.docuseal.com/webhooks
```

---

## Implementation Status Tracking

### Phase Checklist

- [ ] **Phase 1:** Foundation & Configuration (2-3h)
  - [ ] Rails credentials configured
  - [ ] DocuSeal initializer created
  - [ ] Faraday gem added
  - [ ] Active Storage verified

- [ ] **Phase 2:** Service Layer Implementation (8-10h)
  - [ ] DocusealService created
  - [ ] TradeDocumentService created
  - [ ] TradeService updated

- [ ] **Phase 3:** Controllers & Routes (4-5h)
  - [ ] TradesController updated
  - [ ] TradeDocumentsController created
  - [ ] Webhooks::DocusealController created
  - [ ] Routes configured

- [ ] **Phase 4:** Background Jobs (2-3h)
  - [ ] SignatureDeadlineCheckJob created
  - [ ] Cron/recurring job configured
  - [ ] Optional: Polling job created

- [ ] **Phase 5:** View Layer (4-6h)
  - [ ] Trade show page updated
  - [ ] DocuSeal embed partial created
  - [ ] Trade documents views created (optional)

- [ ] **Phase 6:** Email Notifications (2-3h)
  - [ ] TradeMailer methods created
  - [ ] Email templates created
  - [ ] Trade model callbacks updated

- [ ] **Phase 7:** DocuSeal Template Setup (1-2h)
  - [ ] Template created in DocuSeal dashboard
  - [ ] Webhook configured
  - [ ] Testing script created
  - [ ] Template tested

- [ ] **Phase 8:** Helper & Utility Updates (1-2h)
  - [ ] Trade model helper methods added
  - [ ] Active Storage association added
  - [ ] Policy updates completed
  - [ ] Enum syntax fixed

- [ ] **Phase 9:** Testing & Integration (4-6h)
  - [ ] Service tests written
  - [ ] Controller tests written
  - [ ] Integration tests written
  - [ ] Manual testing completed

- [ ] **Phase 10:** Migration & Deployment (2-3h)
  - [ ] Legacy trade migration created
  - [ ] Documentation updated
  - [ ] Deployment checklist completed
  - [ ] Production deployment successful

---

## Timeline Estimates

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1 | 2-3 hours | None |
| Phase 2 | 8-10 hours | Phase 1 |
| Phase 3 | 4-5 hours | Phase 2 |
| Phase 4 | 2-3 hours | Phase 2, 3 |
| Phase 5 | 4-6 hours | Phase 3 |
| Phase 6 | 2-3 hours | Phase 2 |
| Phase 7 | 1-2 hours | Phase 1 |
| Phase 8 | 1-2 hours | Phase 2, 3 |
| Phase 9 | 4-6 hours | Phase 2-8 |
| Phase 10 | 2-3 hours | Phase 9 |

**Total: 30-43 hours** (approximately 1 week of focused development)

---

## Key Success Criteria

1. ✅ Seller can initiate signature request from draft trade
2. ✅ Sequential signing: Seller signs first, then buyer
3. ✅ DocuSeal embedded iframe loads in Trade show page
4. ✅ Webhooks process signature completions correctly
5. ✅ Signed PDF is stored and downloadable via Active Storage
6. ✅ Trade locked during signature process
7. ✅ Deadline expiration handled gracefully with retry option
8. ✅ Email notifications sent at key milestones
9. ✅ State transitions work: draft → awaiting signatures → awaiting_funding
10. ✅ Cancellation and retry flows work correctly

---

## Notes & Decisions

### Configuration Pattern
Following existing Digital Ocean Spaces pattern in `storage.yml`, all DocuSeal configuration will be loaded from Rails encrypted credentials via an initializer, NOT environment variables. This provides:
- Consistent credential management
- Better security (encrypted at rest)
- Environment-specific configs (dev/staging/production)
- No need for .env files

### Active Storage
Using Active Storage (already configured) for signed PDF storage instead of direct S3 SDK calls. Benefits:
- Consistent with Rails conventions
- Built-in URL generation
- Automatic cleanup
- Direct association with Trade model

### Workflow Decision
The DocuSeal signature flow will be the PRIMARY flow for all new trades. The old "send_to_buyer" → "agree" pattern will remain in place for legacy trades but new trades should use signatures for legal compliance.

### State Machine
The signature states integrate seamlessly with existing state machine. No modifications to database schema needed - all fields already exist.

---

## Troubleshooting Guide

### Common Issues

**Issue:** DocuSeal iframe doesn't load
- **Check:** Browser console for CORS errors
- **Fix:** Verify `api.docuseal.com` in allowed_redirect_hosts.rb
- **Fix:** Check signing URL is valid (expires after 24h)

**Issue:** Webhook not processing
- **Check:** DocuSeal dashboard webhook delivery logs
- **Fix:** Verify webhook URL is publicly accessible
- **Fix:** Check webhook secret matches in credentials
- **Fix:** Review Rails logs for signature verification failures

**Issue:** Signed PDF not downloading
- **Check:** Active Storage configuration
- **Fix:** Verify Digital Ocean Spaces credentials
- **Fix:** Check bucket permissions
- **Fix:** Review logs for upload failures

**Issue:** Trade stuck in signature state
- **Check:** TradeDocument status
- **Fix:** Check DocuSeal submission status via API
- **Fix:** Re-trigger webhook manually
- **Fix:** Run deadline check job manually

**Issue:** Email notifications not sending
- **Check:** ActionMailer configuration
- **Fix:** Verify email service credentials
- **Fix:** Check job queue is processing
- **Fix:** Review mailer logs

---

## Reference Files

### Source Repository (escrow_next)
- DocusealService: `/Users/briancarpenter/development/escrow_next/backend/app/services/docuseal_service.rb`
- TradeDocumentService: `/Users/briancarpenter/development/escrow_next/backend/app/services/trade_document_service.rb`
- Webhook Controller: `/Users/briancarpenter/development/escrow_next/backend/app/controllers/api/v1/webhooks/docuseal_controller.rb`
- Template Spec: `/Users/briancarpenter/development/escrow_next/docs/docuseal/DOCUSEAL_TEMPLATE_SPECIFICATION.md`

### Target Repository (nexlock)
- Trade Model: `/Users/briancarpenter/development/nexlock/app/models/trade.rb`
- Schema: `/Users/briancarpenter/development/nexlock/db/schema.rb`
- This Document: `/Users/briancarpenter/development/nexlock/docs/DOCUSEAL_IMPLEMENTATION_PLAN.md`

---

**Last Updated:** 2025-10-22
**Status:** Planning Complete - Ready for Implementation
