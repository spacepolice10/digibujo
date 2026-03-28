class Card < ApplicationRecord
  include Taggable, Completable, Archivable, Pinnable, Poppable, Publishable

  scope :timeline,               -> { where.not(cardable_type: 'Draft') }
  scope :timeline_chronological, -> { timeline.order(created_at: :desc) }
  scope :temporal, -> { timeline.where.not(date: nil) }

  belongs_to :user
  delegated_type :cardable, types: %w[Draft Task Note Event Daylog], dependent: :destroy
  accepts_nested_attributes_for :cardable

  has_rich_text :content
  validates :content, presence: true

  delegate :completable?, :temporal?, :taggable?, :icon, :colour, :name, :marker, to: :cardable

  def type_icon_variable = "var(--icon-#{cardable.icon})"
  def type_name          = cardable.name

  def title
    content.to_plain_text.lines.first&.strip&.truncate(200).presence || 'Untitled'
  end

  def self.type_capabilities(type_name)
    type_name.constantize.capabilities
  end
end
