# frozen_string_literal: true

class Person < ApplicationRecord
  include Colourable, Iconable, Pinnable, Person::Searchable, ActionText::Attachable

  belongs_to :user
  has_many :bullet_people, dependent: :destroy
  has_many :bullets, through: :bullet_people
  has_many :handles, -> { order(:position, :id) }, class_name: "Person::Handle", dependent: :destroy, inverse_of: :person
  has_one_attached :avatar

  accepts_nested_attributes_for :handles, allow_destroy: true, reject_if: proc { |attrs| attrs["data"].blank? }

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
