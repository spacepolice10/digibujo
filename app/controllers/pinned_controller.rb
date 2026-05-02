class PinnedController < ApplicationController
  def index
    @pinned_bullets = Current.user.bullets.includes(:project).pinned.order(updated_at: :desc)
    @playlists = Current.user.playlists.includes(playlist_bullets: { bullet: :project }).order(created_at: :desc)
  end
end
