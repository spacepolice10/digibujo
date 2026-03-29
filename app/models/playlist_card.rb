# frozen_string_literal: true

class PlaylistCard < ApplicationRecord
  belongs_to :playlist
  belongs_to :card

  validates :card_id, uniqueness: { scope: :playlist_id }
end
