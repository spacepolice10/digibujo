# frozen_string_literal: true

class Collection < ApplicationRecord
  include Archivable, Colourable, Iconable, Collection::Searchable, Collection::NameMatching

  belongs_to :user
  has_many :bullet_collections, dependent: :destroy
  has_many :bullets, through: :bullet_collections

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :description, length: { maximum: 280 }, allow_blank: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  def colour_variable = Colourable.colour_variable_of(colour)
end
