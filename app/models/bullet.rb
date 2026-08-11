# frozen_string_literal: true

class Bullet < ApplicationRecord
  EXCERPT_LIMIT = 400

  include Migratable, Collectable, Postponable, Archivable, Pinnable, Publishable, Bullet::Pageable,
          Bullet::Projectable, Bullet::Searchable, ActivityTrackable
  belongs_to :user
  belongs_to :bucket
  has_many :activities, as: :subject, dependent: :destroy

  has_rich_text :body

  delegated_type :bulletable, types: %w[Task Note Event Voice], dependent: :destroy, optional: true, inverse_of: :bullet
  delegate :completable?, :temporal?,
           :marker_icon, :completed?,
           :starts_date, :ends_date, :data_attributes,
           :icon, :colour,
           to: :bulletable

  accepts_nested_attributes_for :bulletable
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true
  validates :author_name, length: { maximum: 100 }, allow_blank: true

  before_validation :ensure_bulletable, on: :create

  def body_as_text = body.to_plain_text.to_s
  def name         = body_as_text.lines.first&.strip.presence || 'Untitled'
  def long?        = body_as_text.length > EXCERPT_LIMIT
  def excerpt      = bulletable.excerpt_for(body)

  scope :active, -> { where.missing(:archive) }
  scope :scheduled, -> { where.not(pops_on: nil) }
  scope :unscheduled, -> { where(pops_on: nil) }
  scope :limited_by_column, lambda { |column, number: 5|
    quoted_table  = connection.quote_table_name(table_name)
    quoted_column = connection.quote_column_name(column)

    ranked = select(
      "#{quoted_table}.*, ROW_NUMBER() OVER (PARTITION BY #{quoted_table}.#{quoted_column} ORDER BY #{quoted_table}.created_at ASC, #{quoted_table}.id ASC) AS bullet_rank"
    )

    unscoped.from(ranked, table_name).where('bullet_rank <= ?', number)
  }

  scope :in_review, lambda { |range|
    active
      .joins(:bucket)
      .where(buckets: { bucketable_type: 'Daylog' }, pops_on: range, migrated_at: nil)
  }

  def to_partial_path
    bulletable.to_partial_path
  end

  def migration_activity
    return unless migrated?

    activities.where(action: last_migration['action']).order(created_at: :desc).first
  end

  private

  def ensure_bulletable
    build_bulletable if bulletable.blank?
  end
end
