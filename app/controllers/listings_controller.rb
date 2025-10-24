# frozen_string_literal: true

class ListingsController < ApplicationController
  before_action :set_trade, only: [:show]
  before_action :track_view, only: [:show]

  def show
    # Public listing page - no authentication required
    @trade = Trade.find_by!(invitation_token: params[:token])

    unless @trade.published? && @trade.listing_status == 'published'
      redirect_to root_path, alert: "This listing is not available."
      return
    end

    # Check if listing is expired
    if @trade.listing_expires_at.present? && @trade.listing_expires_at < Time.current
      redirect_to root_path, alert: "This listing has expired."
      return
    end
  end

  private

  def set_trade
    @trade = Trade.find_by!(invitation_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Listing not found."
  end

  def track_view
    # Track with Ahoy
    ahoy.track "listing_view", trade_id: @trade.id

    # Update first view timestamp
    @trade.update_column(:buyer_viewed_at, Time.current) if @trade.buyer_viewed_at.nil?

    # Increment counter cache
    @trade.increment!(:view_count)
  end
end
