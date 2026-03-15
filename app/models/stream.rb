class Stream < ApplicationRecord
  belongs_to :user

  store_accessor :fields, :cardable_type, :sorted_by, :date_from, :date_to, :tags

  validates :name, presence: true, uniqueness: { scope: :user_id }

  scope :named, -> { where.not(name: nil) }

  class << self
    def from_params(params, user: nil)
      new(user: user, fields: params.to_h.slice(*fields_keys).compact_blank)
    end

    def fields_keys
      %w[cardable_type sorted_by date_from date_to tags]
    end
  end

  def cards
    scope = user.cards.includes(:tags)
    scope = scope.where(cardable_type: cardable_type) if cardable_type.present?
    scope = scope.where("date >= ?", date_from) if date_from.present?
    scope = scope.where("date <= ?", date_to) if date_to.present?
    scope = filter_by_tags(scope)
    scope = scope.order(created_at: sorted_by == "oldest" ? :asc : :desc)
    scope
  end

  def empty?
    fields.compact_blank.blank?
  end

  private

  def filter_by_tags(scope)
    return scope if tags.blank?

    names = tags.split(",").map(&:strip).reject(&:blank?)
    return scope if names.empty?

    scope.joins(:tags).where(tags: { name: names }).distinct
  end
end
