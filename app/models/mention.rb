# frozen_string_literal: true

# nonbucketable entity to connect bullets between each others using tagging system based on Bullet Journal concept
class Mention < ApplicationRecord
  KIND = {
    'project' => {
      trigger: '#',
      mark: 'hash',
      icon: 'hash',
      name: 'Project',
      content_type: 'application/vnd.actiontext.mention.project',
      activity_mentioned: 'project_mentioned',
      activity_unmentioned: 'project_unmentioned'
    },
    'person' => {
      trigger: '@',
      mark: 'at',
      icon: 'at',
      name: 'Person',
      content_type: 'application/vnd.actiontext.mention.person',
      activity_mentioned: 'person_mentioned',
      activity_unmentioned: 'person_unmentioned'
    }
  }.freeze

  include Colourable, Pinnable, Mention::Searchable, ActionText::Attachable

  belongs_to :user
  has_many :bullet_mentions, dependent: :destroy
  has_many :bullets, through: :bullet_mentions

  enum :kind, { project: 'project', person: 'person' }, validate: true

  validates :name, presence: true
  validates :name, uniqueness: { scope: %i[user_id kind] }

  normalizes :name, with: ->(name) { name.strip.downcase }

  def kind_config
    KIND[kind]
  end

  def trigger
    kind_config[:trigger]
  end

  def mark
    kind_config[:mark]
  end

  def icon
    kind_config[:icon]
  end

  def kind_name
    kind_config[:name]
  end

  def content_type
    kind_config[:content_type]
  end

  def to_attachable_partial_path
    'mentions/attachable'
  end

  def attachable_text_representation(_caption = nil)
    name
  end
end
