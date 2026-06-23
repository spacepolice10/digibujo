# frozen_string_literal: true

class Bullet < ApplicationRecord
  include Migratable, Collectable, Poppable, Bullet::Archivable, Pinnable, Publishable, Projectable, Personable,
          BodyTagSyncable, RichBodySanitizable, Bullet::Searchable, ActivityTrackable

  scope :chronological, -> { order(created_at: :asc) }
  scope :pops_on_date, lambda { |date|
    where(pops_on: date).distinct
  }
  scope :dailylog, ->(date) { pops_on_date(date).active }
  scope :in_timeline, -> { where(bucket_id: nil).active }
  scope :in_review, lambda { |from:, to:|
    in_timeline.where(pops_on: from..to).chronological
  }

  belongs_to :user
  belongs_to :bucket, optional: true

  delegated_type :bulletable, types: %w[Task Note Event Title], dependent: :destroy, optional: true

  DEFAULT_COMPOSER_TYPE = 'Note'
  COMPOSER_TYPE_OPTIONS = [
    { value: 'Task', icon: 'square', modifier: 'task', marker_styles: 'bullet--task-marker', label: 'Task',
      hint: 'Action you can complete' },
    { value: 'Note', icon: 'line-dashed', modifier: 'note', marker_styles: 'bullet--note-marker', label: 'Note',
      hint: 'Reference or log entry' },
    { value: 'Event', icon: 'circle', modifier: 'event', marker_styles: 'bullet--event-marker', label: 'Event',
      hint: 'Scheduled occurrence' },
    { value: 'Title', icon: 'heading', modifier: 'title', marker_styles: '', label: 'Title', hint: 'Section heading' }
  ].freeze
  COMPOSER_ACTION_OPTIONS = [
    { value: 'attachment', icon: 'paperclip', label: 'Attachment', hint: 'Upload files' },
    { value: 'expand', icon: 'expand', label: 'Expand', hint: 'Code, files, markdown' }
  ].freeze
  delegate :completable?, :temporal?, :name, :excerpt,
           :marker_icon, :marker_styles, :completed?, :meta_labels,
           :mood_marker, to: :bulletable

  accepts_nested_attributes_for :bulletable

  has_rich_text :body
  has_rich_text :rich_body
  has_many_attached :attachments

  validate :body_or_rich_body_present
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true

  def rich_body?
    rich_body.present? && rich_body.to_plain_text.present?
  end

  private

  def body_or_rich_body_present
    return if body.present? || rich_body.present?
    return if attachments.attached?

    errors.add(:body, "can't be blank")
  end
end
