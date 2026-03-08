class Card < ApplicationRecord
  include Pinnable
  include Archivable
  include Taggable

  enum :status, { active: "active", pinned: "pinned", archived: "archived" }
  scope :draft,          -> { where(cardable_type: "Draft") }
  scope :popped,         -> { active.where("pops_on IS NOT NULL AND pops_on <= ?", Date.today) }
  scope :timeline,       -> { active.where("pops_on IS NULL OR pops_on > ?", Date.today) }
  scope :timeline_order, -> { timeline.order(created_at: :desc) }

  belongs_to :user
  delegated_type :cardable, types: %w[Draft Task Note], dependent: :destroy

  has_rich_text :content

  def draft?
    cardable_type == "Draft"
  end

  delegate :completable?, :temporal?, :taggable?, to: :cardable

  def done?
    completable? && cardable.done?
  end

  def type_label
    cardable_type
  end

  def popped?
    pops_on.present? && pops_on <= Date.today
  end

  def title
    content.to_plain_text.lines.first&.strip.presence || "Untitled"
  end

  def self.type_capabilities(type_name)
    type_name.safe_constantize&.capabilities || Draft.capabilities
  end
end
