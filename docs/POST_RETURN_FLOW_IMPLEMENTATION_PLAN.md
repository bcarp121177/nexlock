MVP Implementation Plan

  Based on my review of your codebase, here's the implementation plan:

  Current State Analysis:

  - ✅ Trade state machine fully implemented with all states/events
  - ✅ Stripe integration for payments and payouts working
  - ✅ Noticed gem already installed (Jumpstart Pro)
  - ✅ Madmin admin dashboard already available
  - ✅ Postmark/Resend support already configured (using Resend per jumpstart.yml)
  - ✅ process_refund method exists but StripeService.create_refund is missing
  - ✅ Dispute model exists with basic structure

  ---
  Implementation Tasks:

  1. Stripe Refund Implementation (2-3 hrs)

  Files to modify:
  - app/services/stripe_service.rb - Add create_refund method
  - app/controllers/webhooks/stripe_controller.rb - Add charge.refunded handler
  - app/models/escrow.rb - Verify columns exist (status, refunded_at)

  Tasks:
  1. Add StripeService.create_refund(trade) method using Payment Intent refunds
  2. Add webhook handler for charge.refunded
  3. Update escrow status tracking
  4. Test: Create trade → Fund → Reject → Accept return → Verify refund processed

  ---
  2. Email Notifications with Noticed (6-8 hrs)

  Many of these messages might exist in the ../escrow_next application.  Look there to see what content can/should be repurposed.

  Files to create:
  - app/notifiers/trade/funded_notifier.rb
  - app/notifiers/trade/shipped_notifier.rb
  - app/notifiers/trade/delivered_notifier.rb
  - app/notifiers/trade/accepted_notifier.rb
  - app/notifiers/trade/rejected_notifier.rb
  - app/notifiers/trade/return_accepted_notifier.rb
  - app/notifiers/trade/refunded_notifier.rb
  - app/mailers/trade_mailer.rb
  - Email view templates (7 files in app/views/trade_mailer/)

  Files to modify:
  - app/services/notification_service.rb - Replace stubs with Noticed calls

  Tasks:
  1. Create 7 Noticed notifier classes (inherit from ApplicationNotifier)
  2. Create TradeMailer with 7 methods
  3. Create 7 HTML email templates
  4. Update NotificationService to trigger notifications
  5. Configure Resend API key (already set as email provider)
  6. Test all 7 notification paths

  ---
  3. Dispute Management Dashboard (8-10 hrs)

  Files to create:
  - app/controllers/madmin/disputes_controller.rb
  - app/controllers/madmin/trades_controller.rb (if not exists)
  - app/views/madmin/disputes/show.html.erb (custom view)

  Files to modify:
  - app/models/dispute.rb - Add resolution_data column/methods
  - config/routes.rb - Add madmin routes for disputes

  Tasks:
  1. Create Madmin resource for Disputes model
  2. Add custom show page with:
    - Trade details panel
    - Buyer/Seller info
    - Evidence display
    - 3 resolution buttons (refund buyer, release seller, split 50/50)
  3. Add member actions for resolutions that call:
    - trade.resolve_with_refund!
    - trade.resolve_with_release!
    - trade.resolve_with_split! (with resolution_data)
  4. Wire up to existing Trade state machine events
  5. Add dispute status filters
  6. Test all 3 resolution paths

  ---
  Estimated Timeline:

  | Task                | Hours     | Priority |
  |---------------------|-----------|----------|
  | Stripe Refunds      | 2-3       | HIGH     |
  | Email Notifications | 6-8       | HIGH     |
  | Dispute Dashboard   | 8-10      | MEDIUM   |
  | Total               | 16-21 hrs |          |

  ---
  Dependencies & Considerations:

  ✅ Already in place:
  - Noticed gem (v2.2)
  - Madmin dashboard framework
  - Resend email provider configured
  - Stripe gem (v15.0)
  - All Trade state machine events
  - Dispute model structure

  ⚠️ Need to verify:
  - Resend API key in credentials/ENV
  - Stripe webhook endpoint configured for charge.refunded
  - Escrow table has refunded_at column
  - Dispute table has resolution_data jsonb column

  📝 Implementation notes:
  - Use Resend instead of Postmark (already configured in jumpstart.yml)
  - Madmin already available (no need for ActiveAdmin)
  - All state machine transitions already working
  - Focus on simple, clean UI for dispute resolution

  ---
  Recommended Implementation Order:

  1. Week 1: Stripe Refunds + Basic email notifications (4 critical ones)
  2. Week 2: Complete email notifications + Dispute dashboard
  3. Week 3: Testing, refinements, documentation