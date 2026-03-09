class Card < ApplicationRecord
  include Pinnable, Archivable, Completable, Taggable

  enum :status, { active: "active", pinned: "pinned", archived: "archived" }
  scope :popped,                 -> { active.where("pops_on IS NOT NULL AND pops_on <= ?", Date.today) }
  scope :timeline,               -> { active.where("pops_on IS NULL OR pops_on > ?", Date.today) }
  scope :timeline_chronological, -> { timeline.order(created_at: :desc) }

  belongs_to :user
  delegated_type :cardable, types: %w[Draft Task Note], dependent: :destroy

  has_rich_text :content

  delegate :completable?, :temporal?, :taggable?, to: :cardable

  def popped?
    pops_on.present? && pops_on <= Date.today
  end

  def title
    content.to_plain_text.lines.first&.strip.presence || "Untitled"
  end

  def self.type_capabilities(type_name)
    type_name.constantize.capabilities
  end
end
