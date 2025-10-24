# Trade Listing Feature Implementation Plan

## Overview
Add a public listing phase between draft creation and signature workflow, allowing sellers to create shareable listings that buyers can review before committing.

## Current Flow
```
Draft ’ Send for Signature ’ Awaiting Seller Sig ’ Awaiting Buyer Sig ’ ...
(requires buyer_email upfront)
```

## New Flow
```
Draft ’ Publish Listing ’ [Buyer Reviews] ’ Buyer Accepts ’ Send for Signature ’ ...
(buyer_email optional until acceptance)
```

---

## Phase 1: Dependencies

**Add Ahoy gem to Gemfile:**
```ruby
gem "ahoy_matey"
```

Run: `bundle install && rails generate ahoy:install && rails db:migrate`

This provides:
- Visit tracking (ahoy_visits table)
- Event tracking (ahoy_events table)
- Automatic page view tracking
- User association support

---

## Phase 2: Database Migration

**Add to `trades` table:**
- `published_at` (datetime) - timestamp when listing published
- `listing_status` (string, default: 'draft') - enum: draft, published, accepted, expired
- `buyer_viewed_at` (datetime) - first view timestamp
- `listing_expires_at` (datetime) - optional expiration
- `view_count` (integer, default: 0) - cache counter

**Modify validations:**
- Make `buyer_email` conditional (only required for states >= awaiting_seller_signature)

---

## Phase 3: State Machine Updates

**Add new state:**
- `published` - between draft and awaiting_seller_signature

**New events:**
- `publish_listing` - draft ’ published (generates shareable link)
- `unpublish_listing` - published ’ draft
- `buyer_accepts_listing` - published ’ published (buyer info captured)
- Modified `send_for_signature` - now requires `published` state with buyer info

---

## Phase 4: Routes

**Public routes (no authentication):**
```ruby
get '/l/:token', to: 'listings#show', as: :public_listing
post '/l/:token/accept', to: 'listings#accept'
```

**Authenticated routes:**
```ruby
resources :trades do
  member do
    post :publish_listing
    post :unpublish_listing
    get :listing_preview
    get :listing_analytics  # View Ahoy analytics
  end
end
```

---

## Phase 5: Controllers & Services

**New: `ListingsController` (public, inherits from ApplicationController)**
- `show` - Display public listing (uses invitation_token)
  - Tracks page view with Ahoy
  - Increments view_count counter cache
  - Updates buyer_viewed_at on first view
- `accept` - Buyer provides info and accepts terms

**Updated: `TradesController`**
- `publish_listing` - Seller action to publish
- `unpublish_listing` - Seller unpublishes
- `listing_preview` - Preview as buyer would see
- `listing_analytics` - Show Ahoy visit/event data

**Updated: `TradeService`**
- `publish_listing(trade)` - Set published_at, listing_status
- `accept_listing(trade, buyer_params)` - Capture buyer info
- Modified `send_for_signature` - check for buyer info first

---

## Phase 6: Views

**`app/views/listings/show.html.erb` (PUBLIC)**
- Clean layout (no authenticated app header/footer)
- Item gallery (media attachments)
- Item details (name, description, category, condition)
- Price breakdown
- Terms section (inspection, fees, return policy)
- Limited seller info
- "Accept & Continue" CTA button
- View counter display

**Buyer acceptance modal/page:**
- Form collecting:
  - Full name
  - Email
  - Phone (optional)
  - Shipping address (all fields)
- Legal agreement checkbox
- Submit ’ captures info and triggers signature flow

**Seller listing management:**
- "Publish Listing" button on draft trades
- Shows shareable link with copy button
- View/accept stats from Ahoy
- "Unpublish" option

---

## Phase 7: Model Changes

**`app/models/trade.rb`:**
```ruby
# Ahoy associations
has_many :ahoy_events, as: :eventable, class_name: "Ahoy::Event"

# Conditional validations
validates :buyer_email, presence: true,
          if: -> { state.in?(%w[awaiting_seller_signature awaiting_buyer_signature ...]) }

# Scopes
scope :published_listings, -> { where(listing_status: 'published') }
scope :active_listings, -> { published_listings.where('listing_expires_at IS NULL OR listing_expires_at > ?', Time.current) }

# Methods
def listing_url
  Rails.application.routes.url_helpers.public_listing_url(invitation_token, host: ENV['APP_HOST'])
end

def can_publish?
  draft? && item.present? && price_cents.present?
end

def buyer_info_complete?
  buyer_email.present? && buyer_name.present? && buyer_street1.present? # etc.
end

# Ahoy analytics helpers
def unique_visitors_count
  Ahoy::Visit.where(visit_token: ahoy_events.select(:visit_token)).distinct.count
end

def listing_views_count
  ahoy_events.where(name: 'listing_view').count
end
```

---

## Phase 8: State Machine Events

```ruby
event :publish_listing do
  transitions from: :draft, to: :published,
              guard: :can_publish?,
              after: :mark_published
end

event :unpublish_listing do
  transitions from: :published, to: :draft,
              after: :mark_unpublished
end

event :buyer_accepts_listing do
  transitions from: :published, to: :published,
              guard: :buyer_info_complete?,
              after: :notify_seller_of_acceptance
end

event :send_for_signature do
  transitions from: :published,  # changed from :draft
              to: :awaiting_seller_signature,
              guard: [:can_send_for_signature?, :buyer_info_complete?],
              after: [:lock_for_editing, :create_signature_document]
end
```

**Callback methods:**
```ruby
def mark_published
  update_columns(published_at: Time.current, listing_status: 'published')
  Rails.logger.info "Trade #{id} published as listing"
end

def mark_unpublished
  update_columns(published_at: nil, listing_status: 'draft')
  Rails.logger.info "Trade #{id} unpublished"
end

def notify_seller_of_acceptance
  # Send notification to seller
  Rails.logger.info "Buyer accepted listing for trade #{id}"
end
```

---

## Phase 9: Ahoy Integration

**Track listing views in `ListingsController#show`:**
```ruby
def show
  @trade = Trade.find_by!(invitation_token: params[:token], listing_status: 'published')

  # Track with Ahoy
  ahoy.track "listing_view", trade_id: @trade.id

  # Update first view timestamp
  @trade.update_column(:buyer_viewed_at, Time.current) if @trade.buyer_viewed_at.nil?

  # Increment counter cache
  @trade.increment!(:view_count)
end
```

**Track acceptance events:**
```ruby
def accept
  # ... after successful acceptance ...
  ahoy.track "listing_accepted", {
    trade_id: @trade.id,
    buyer_email: buyer_params[:buyer_email]
  }
end
```

**Display analytics on seller dashboard:**
```ruby
# app/controllers/trades_controller.rb
def listing_analytics
  @unique_visitors = @trade.unique_visitors_count
  @total_views = @trade.listing_views_count
  @recent_visits = Ahoy::Visit.joins(:events)
    .where(ahoy_events: { name: 'listing_view', eventable: @trade })
    .order(started_at: :desc)
    .limit(10)
end
```

---

## Phase 10: UI/UX Details

**Public listing design:**
- Minimal, clean layout
- Professional presentation
- Mobile-responsive
- OG meta tags for link previews
- JSON-LD structured data (optional)

**Seller dashboard updates:**
- Badge showing "Published" status
- Analytics card: unique visitors, total views, acceptance
- Copy link button with success toast

**Notifications:**
- Seller: "Your listing was viewed" (first view)
- Seller: "Buyer accepted terms"
- Buyer: "Confirmation" after acceptance

---

## Phase 11: Optional Features (V2)

1. **Q&A System** - Allow buyer questions on listing
2. **Multiple Buyers** - Track multiple interested parties
3. **Marketplace** - Browse all public listings
4. **Listing Templates** - Save common listing configurations
5. **Conversion Analytics** - Views ’ Acceptance funnel
6. **Expiration** - Auto-unpublish after X days
7. **Featured Listings** - Promoted placement

---

## Testing Checklist

- [ ] Install and configure Ahoy gem
- [ ] Create draft trade without buyer_email
- [ ] Publish listing ’ generates shareable URL
- [ ] Visit public URL (logged out) ’ see listing
- [ ] Verify Ahoy tracks visit
- [ ] Check view_count increments
- [ ] Submit buyer acceptance form
- [ ] Verify buyer info captured
- [ ] Send for signature ’ generates PDF with buyer data
- [ ] Complete signature workflow
- [ ] Test unpublish functionality
- [ ] View analytics dashboard

---

## Estimated Effort

- **Phase 1** (Ahoy Setup): 1 hour
- **Phase 2** (Database Migration): 1 hour
- **Phase 3-4** (State Machine + Routes): 2 hours
- **Phase 5** (Controllers + Services): 3-4 hours
- **Phase 6** (Views + UI): 4-6 hours
- **Phase 7-8** (Models + Events): 2-3 hours
- **Phase 9** (Ahoy Integration): 2 hours
- **Phase 10** (Polish + Notifications): 2-3 hours
- **Testing**: 2-3 hours

**Total: ~19-26 hours**

---

## Security Considerations

- Rate limit public listing access
- Validate invitation_token on every request
- Prevent listing enumeration
- Sanitize buyer-provided inputs
- Add CAPTCHA to acceptance form (optional)
- Log all buyer actions for audit trail
- Ahoy automatically anonymizes IPs (GDPR friendly)
