class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_variant
  before_action :set_latest_playlist

  private

  def set_variant
    request.variant = :mobile if request.user_agent&.match?(/Mobile|Android|iPhone/i)
  end

  def set_latest_playlist
    return unless Current.user

    @latest_playlist = Current.user.playlists.order(created_at: :desc).first
    @playlist_card_map = @latest_playlist&.playlist_cards&.index_by(&:card_id) || {}
  end
end
