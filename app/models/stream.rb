class Stream < ApplicationRecord
  belongs_to :user

  # colour values reference --model-color-N CSS custom properties
  DEFAULTS = [
    { name: "Drafts",  position: 0, fields: { "cardable_type" => "Draft",  "icon" => "pencil",       "colour" => "7" } },
    { name: "Tasks",   position: 1, fields: { "cardable_type" => "Task",   "icon" => "circle-check", "colour" => "2" } },
    { name: "Notes",   position: 2, fields: { "cardable_type" => "Note",   "icon" => "file",         "colour" => "5" } },
    { name: "Events",  position: 3, fields: { "cardable_type" => "Event",  "icon" => "calendar",     "colour" => "6" } },
    { name: "Daylogs", position: 4, fields: { "cardable_type" => "Daylog", "icon" => "book",         "colour" => "4" } }
  ].freeze

  store_accessor :fields, :cardable_type, :sorted_by, :date_from, :date_to, :tags, :icon, :colour

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validate :name_immutable_on_default, on: :update

  before_destroy :prevent_default_destruction

  scope :ordered, -> { order(Arel.sql("position IS NULL, position ASC, created_at ASC")) }

  class << self
    def fields_keys
      %w[cardable_type sorted_by date_from date_to tags icon colour]
    end
  end

  def cards
    scope = user.cards.includes(:tags)
    scope = filter_by_cardable_type(scope)
    scope = filter_by_date_from(scope)
    scope = scope.where("date <= ?", date_to) if date_to.present?
    scope = filter_by_tags(scope)
    scope = scope.order(created_at: sorted_by == "oldest" ? :asc : :desc)
    scope
  end

  def empty?
    fields.except("icon", "colour").compact_blank.blank?
  end

  private

  def filter_by_cardable_type(scope)
    return scope if cardable_type.blank?

    types = cardable_type.split(",").map(&:strip).reject(&:blank?)
    return scope if types.empty?

    scope.where(cardable_type: types)
  end

  def filter_by_date_from(scope)
    return scope if date_from.blank?

    resolved = date_from == "today" ? Date.today : date_from
    scope.where("date >= ?", resolved)
  end

  def filter_by_tags(scope)
    return scope if tags.blank?

    names = tags.split(",").map(&:strip).reject(&:blank?)
    return scope if names.empty?

    scope.joins(:tags).where(tags: { name: names }).distinct
  end

  def name_immutable_on_default
    errors.add(:name, "cannot be changed on default streams") if default? && name_changed?
  end

  def prevent_default_destruction
    if default?
      errors.add(:base, "Default streams cannot be deleted")
      throw :abort
    end
  end
end
