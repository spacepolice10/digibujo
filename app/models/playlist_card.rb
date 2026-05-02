# frozen_string_literal: true

class PlaylistCard < ApplicationRecord
  belongs_to :playlist
  belongs_to :bullet

  validates :bullet_id, uniqueness: { scope: :playlist_id }
end
