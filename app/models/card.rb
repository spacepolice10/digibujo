class Card < ApplicationRecord
  include CollectionAssignable, Completable, Collectable, Schedulable, Archivable, Pinnable, Poppable, Publishable

  scope :timeline,               -> { all }
  scope :timeline_chronological, -> { timeline.order(created_at: :desc) } 
  scope :for_day, ->(day) {
    where(date: nil, created_at: day.all_day).or(where(date: day.all_day))
  }
  scope :todays,                 -> { for_day(Date.current) }
  scope :temporal, -> { timeline.where.not(date: nil) }

  belongs_to :user
  belongs_to :collection, optional: true
  belongs_to :context_card, class_name: "Card", optional: true
  delegated_type :cardable, types: %w[Task Note Event], dependent: :destroy
  accepts_nested_attributes_for :cardable

  has_many :playlist_cards, dependent: :destroy
  has_many :playlists, through: :playlist_cards
  has_many :context_for_cards, class_name: "Card", foreign_key: :context_card_id, dependent: :nullify, inverse_of: :context_card

  has_rich_text :content
  validates :content, presence: true
  validates :context_card_id, numericality: { only_integer: true }, allow_nil: true
  validate :context_card_is_not_self
  validate :context_card_belongs_to_same_user

  delegate :completable?, :temporal?, :icon, :colour, :name, :marker, to: :cardable

  def to_partial_path    = cardable.to_partial_path
  def self.type_capabilities(type_name)
    type_name.constantize.capabilities
  end

  def context_name
    context_card&.cardable&.name.presence || "Context"
  end

  private

  def context_card_is_not_self
    return if context_card_id.blank? || id.blank?
    return unless context_card_id == id

    errors.add(:context_card, "can't point to itself")
  end

  def context_card_belongs_to_same_user
    return if context_card.blank? || user.blank?
    return if context_card.user_id == user_id

    errors.add(:context_card, "must belong to the same user")
  end
end
