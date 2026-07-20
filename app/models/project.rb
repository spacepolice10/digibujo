# frozen_string_literal: true

# Tag connecting bullets via #project references (Bullet Journal projects).
class Project < ApplicationRecord
  TRIGGER = '#'
  MARK = 'hash'
  ICON = 'hash'
  CONTENT_TYPE = 'application/vnd.actiontext.mention.project'

  include Colourable, Pinnable, Project::Searchable, ActionText::Attachable

  belongs_to :user
  has_many :bullet_projects, dependent: :destroy
  has_many :bullets, through: :bullet_projects

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }

  normalizes :name, with: ->(name) { name.strip.downcase }

  def trigger = TRIGGER
  def mark = MARK
  def icon = ICON
  def kind_name = 'Project'
  def content_type = CONTENT_TYPE

  def to_attachable_partial_path
    'projects/attachable'
  end

  def attachable_text_representation(_caption = nil)
    name
  end
end
