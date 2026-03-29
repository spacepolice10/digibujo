# frozen_string_literal: true

class Playlist < ApplicationRecord
  include Colourable, Iconable

  belongs_to :user
  has_many :playlist_cards, -> { order(:position) }, dependent: :destroy
  has_many :cards, through: :playlist_cards

  before_create :auto_assign_identity

  private

  def auto_assign_identity
    index = user.playlists.count
    self.colour = Colourable::COLOUR_KEYS[index % Colourable::COLOUR_KEYS.size]
    self.icon = Iconable::ICON_KEYS[index % Iconable::ICON_KEYS.size]
  end
end
