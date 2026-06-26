# frozen_string_literal: true

class Search::Selection < ApplicationRecord
  LIMIT = 10

  belongs_to :user
  belongs_to :searchable, polymorphic: true

  validates :selected_at, presence: true

  scope :ordered, -> { order(selected_at: :desc) }

  class << self
    def record!(user:, searchable_type:, searchable_id:, query: nil)
      transaction do
        selection = find_or_initialize_by(user:, searchable_type:, searchable_id:)
        selection.update!(selected_at: Time.current, query: query.presence)
        where(user:).ordered.offset(LIMIT).delete_all
      end
    end

    def in_menu(user)
      where(user:).includes(:searchable).ordered.limit(LIMIT).select { |selection| selection.searchable.present? }
    end
  end

end
