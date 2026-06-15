# frozen_string_literal: true

class Person < ApplicationRecord
  include Colourable, Iconable, Pinnable, ActionText::Attachable

  belongs_to :user
  has_many :bullet_people, dependent: :destroy
  has_many :bullets, through: :bullet_people
  has_one_attached :avatar

  validates :name, presence: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  def content_type
    'application/vnd.actiontext.person'
  end

  def to_attachable_partial_path
    'people/attachable'
  end

  def attachable_plain_text_representation(_caption = nil)
    name
  end
end
