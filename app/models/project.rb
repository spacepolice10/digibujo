# frozen_string_literal: true

class Project < ApplicationRecord
  include Colourable, Iconable, Pinnable, Searchable, ActionText::Attachable

  belongs_to :user
  has_many :bullet_projects, dependent: :destroy
  has_many :bullets, through: :bullet_projects
  has_many :search_selections, as: :searchable, dependent: :destroy, class_name: "Search::Selection"

  validates :name, presence: true

  normalizes :name, with: ->(name) { name.strip.downcase }

  def content_type
    'application/vnd.actiontext.project'
  end

  def to_attachable_partial_path
    'projects/attachable'
  end

  def attachable_plain_text_representation(_caption = nil)
    name
  end

  def search_name
    name
  end

  def search_body
    name
  end
end
