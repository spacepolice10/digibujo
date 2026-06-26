# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Migratable, Collectable, Poppable, Bullet::Archivable, Pinnable, Publishable, Bullet::Mentionable,
          Bullet::Searchable, ActivityTrackable

  scope :chronological, -> { order(created_at: :asc) }
  scope :tagged_with_person, ->(person) { joins(:people).where(people: { id: person.id }) }
  scope :tagged_with_project, ->(project) { joins(:projects).where(projects: { id: project.id }) }
  scope :in_bucket, ->(bucket) { where(bucket_id: bucket.id) }
  scope :pops_on_date, lambda { |date|
    where(pops_on: date).distinct
  }
  scope :dailylog, ->(date) { pops_on_date(date).active }
  scope :in_timeline, -> { where(bucket_id: nil).active }
  scope :in_review, lambda { |from:, to:|
    in_timeline.where(migrated_at: nil).where(pops_on: from..to).chronological
  }

  belongs_to :user
  belongs_to :bucket, optional: true

  delegated_type :bulletable, types: %w[Task Note Event], dependent: :destroy, optional: true

  delegate :completable?, :temporal?, :name, :excerpt,
           :marker_icon, :marker_styles, :completed?, :mood_marker,
           :starts_date, :ends_date,
           :shows_marker?, :list_link_uses_excerpt?, :compact_list_name_class,
           :actiontext_preset, :editor_multiline?, :editor_placeholder, :editor_container_class,
           :accepts_editor_attachments?, :submit_on_enter?, :submit_on_command_return?,
           :close_composer_on_submit?,
           to: :bulletable

  accepts_nested_attributes_for :bulletable

  has_rich_text :body

  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true

  def to_partial_path = bulletable.to_partial_path
end
