class Bullet < ApplicationRecord
  include ProjectAssignable, Contextable, Collectable, Schedulable, Archivable, Pinnable, Publishable

  scope :timeline,               -> { all }
  scope :timeline_chronological, -> { timeline.order(created_at: :desc) }
  scope :scheduled_on_date, lambda { |date|
    where(scheduled_on: date)
      .or(where(scheduled_on: nil, created_at: date.beginning_of_day..date.end_of_day))
      .distinct
  }
  scope :triage_on_date, lambda { |date|
    start_t = date.beginning_of_day
    end_t   = date.end_of_day
    scheduled_on_date(date).where(
      "triaged_at IS NULL OR triaged_at < ? OR triaged_at > ?",
      start_t,
      end_t
    )
  }
  scope :todays, -> { scheduled_on_date(Date.current) }
  scope :temporal, -> { timeline.where.not(scheduled_on: nil) }

  belongs_to :user
  belongs_to :project, optional: true
  delegated_type :bulletable, types: %w[Task Note Event], dependent: :destroy, optional: true
  delegate :completable?, :temporal?, :icon, :colour, :name, :marker, to: :bulletable
  accepts_nested_attributes_for :bulletable

  has_many :playlist_bullets,
           class_name: 'PlaylistCard',
           foreign_key: :bullet_id,
           inverse_of: :bullet,
           dependent: :destroy
  has_many :playlists, through: :playlist_bullets
  has_rich_text :content

  validates :content, presence: true
  validates :bulletable_type, inclusion: { in: ->(bullet) { bullet.class.bulletable_types } }
  validates :bulletable, presence: true, if: :known_bulletable_type?

  def to_partial_path = bulletable.to_partial_path

  def self.type_capabilities(type_name)
    return Bulletable::DEFAULT_CAPABILITIES unless bulletable_types.include?(type_name)

    type_name.constantize.capabilities
  end

  private

  def known_bulletable_type?
    bulletable_type.present? && self.class.bulletable_types.include?(bulletable_type.to_s)
  end
end
