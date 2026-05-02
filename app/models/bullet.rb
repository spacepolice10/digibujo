class Bullet < ApplicationRecord
  include ProjectAssignable, Contextable, Completable, Collectable, Schedulable, Archivable, Pinnable, Publishable

  scope :timeline,               -> { all }
  scope :timeline_chronological, -> { timeline.order(created_at: :desc) }
  scope :scheduled_on_date, lambda { |date|
    where(scheduled_on: date)
      .or(where(scheduled_on: nil, created_at: date.beginning_of_day..date.end_of_day))
      .distinct
  }
  scope :triage_on_date, lambda { |date|
    scheduled_on_date(date).where.not(triaged_at: date.beginning_of_day..date.end_of_day)
  }
  scope :todays, -> { scheduled_on_date(Date.current) }
  scope :temporal, -> { timeline.where.not(scheduled_on: nil) }

  belongs_to :user
  belongs_to :project, optional: true
  delegated_type :bulletable, types: %w[Task Note Event], dependent: :destroy
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

  def to_partial_path = bulletable.to_partial_path

  def self.create_with_bulletable(user:, bulletable_type:, bullet_attributes:, bulletable_attributes:)
    klass = bulletable_type.to_s.classify.safe_constantize
    unless klass && bulletable_types.include?(klass.name)
      bullet = user.bullets.new(bullet_attributes)
      bullet.errors.add(:bulletable_type, 'is not included in the list')
      return bullet
    end

    bullet = user.bullets.new(bullet_attributes)
    bullet.bulletable = klass.new(bulletable_attributes || {})
    bullet.save
    bullet
  end

  def self.type_capabilities(type_name)
    type_name.to_s.classify.safe_constantize&.capabilities || Bulletable::DEFAULT_CAPABILITIES
  end
end
