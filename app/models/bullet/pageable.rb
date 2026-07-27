# frozen_string_literal: true

# Chat-style paging for the daylog: pages are keyed on the oldest row already on
# screen instead of an offset, so rows appended by the composer never shift the
# window under the reader.
module Bullet::Pageable
  extend ActiveSupport::Concern

  PAGE_SIZE = 30

  included do
    scope :chronologically, -> { order(created_at: :asc, id: :asc) }

    # created_at alone is not unique — a burst of composer sends can share a
    # timestamp — so the id breaks the tie.
    scope :older_than, lambda { |bullet|
      where(
        'bullets.created_at < :created_at OR (bullets.created_at = :created_at AND bullets.id < :id)',
        created_at: bullet.created_at, id: bullet.id
      )
    }
  end

  class_methods do
    # `last` flips the order in SQL and hands the array back in reading order,
    # so the newest page costs one query and no OFFSET.
    def last_page(size: PAGE_SIZE)
      chronologically.last(size)
    end

    def page_before(bullet, size: PAGE_SIZE)
      older_than(bullet).last_page(size: size)
    end
  end
end
