class Stream < ApplicationRecord
  include Colourable
  include Iconable

  belongs_to :user

  store_accessor :fields, :cardable_type, :sorted_by, :date_from, :date_to, :tags, :icon, :colour

  validates :name, presence: true, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(created_at: :asc) }

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
end
