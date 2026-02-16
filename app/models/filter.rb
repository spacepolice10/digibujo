class Filter < ApplicationRecord
  belongs_to :user

  store_accessor :fields, :cardable_type, :sorted_by

  scope :named, -> { where.not(name: nil) }

  class << self
    def from_params(params)
      new(fields: params.to_h.slice(*fields_keys).compact_blank)
    end

    def fields_keys
      %w[cardable_type sorted_by]
    end
  end

  def cards
    scope = user.cards
    scope = scope.where(cardable_type: cardable_type) if cardable_type.present?
    scope = scope.order(created_at: sorted_by == "oldest" ? :asc : :desc)
    scope
  end

  def empty?
    fields.compact_blank.blank?
  end
end
