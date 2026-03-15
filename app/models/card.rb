class Card < ApplicationRecord
  include Pinnable, Archivable, Completable, Taggable

  scope :timeline,               -> { all }
  scope :timeline_chronological, -> { timeline.order(created_at: :desc) }

  belongs_to :user
  delegated_type :cardable, types: %w[Draft Task Note Event Daylog], dependent: :destroy

  has_rich_text :content
  validates :content, presence: true

  delegate :completable?, :temporal?, :taggable?, to: :cardable

  def popped?
    pops_on.present? && pops_on <= Date.today
  end

  def title
    content.to_plain_text.lines.first&.strip&.truncate(100).presence || "Untitled"
  end

  def self.type_capabilities(type_name)
    type_name.constantize.capabilities
  end
end
