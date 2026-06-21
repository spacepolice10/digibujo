# frozen_string_literal: true

class Search::Selection < ApplicationRecord
  self.table_name = "search_selections"

  STORE_LIMIT = 10
  MENU_LIMIT = 6
  ALLOWED_TYPES = %w[Project Person Bucket Bullet].freeze

  belongs_to :user
  belongs_to :searchable, polymorphic: true

  validates :searchable_type, inclusion: { in: ALLOWED_TYPES }
  validates :selected_at, presence: true

  scope :ordered, -> { order(selected_at: :desc) }

  class << self
    def record!(user:, searchable_type:, searchable_id:, query: nil)
      transaction do
        selection = find_or_initialize_by(user:, searchable_type:, searchable_id:)
        selection.update!(selected_at: Time.current, query: query.presence)
        where(user:).ordered.offset(STORE_LIMIT).delete_all
      end
    end

    def for_menu(user)
      where(user:).includes(:searchable).ordered.limit(MENU_LIMIT).select { |selection| selection.searchable.present? }
    end
  end

  def to_entry
    Search::GlobalRequest::Entry.new(
      entity: searchable,
      rank: 0,
      searchable_type: searchable_type
    )
  end
end
