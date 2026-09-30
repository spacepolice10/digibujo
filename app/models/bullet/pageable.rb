# frozen_string_literal: true

# Chat-style paging: pages are keyed on the oldest row already on screen instead
# of an offset, so rows appended by the composer never shift the window under
# the reader.
#
# Two reading orders exist. Collections read by creation time; the timeline
# reads by the day a bullet belongs to (`pops_on`), then creation time.
module Bullet::Pageable
  extend ActiveSupport::Concern

  PAGE_SIZE = 30

  included do
    scope :chronologically, -> { order(created_at: :asc, id: :asc) }
    scope :by_day, -> { order(pops_on: :asc, created_at: :asc, id: :asc) }

    # created_at alone is not unique — a burst of composer sends can share a
    # timestamp — so the id breaks the tie.
    scope :older_than, lambda { |bullet|
      where(
        'bullets.created_at < :created_at OR (bullets.created_at = :created_at AND bullets.id < :id)',
        created_at: bullet.created_at, id: bullet.id
      )
    }

    scope :earlier_day_than, lambda { |bullet|
      where(
        'bullets.pops_on < :pops_on ' \
        'OR (bullets.pops_on = :pops_on AND bullets.created_at < :created_at) ' \
        'OR (bullets.pops_on = :pops_on AND bullets.created_at = :created_at AND bullets.id < :id)',
        pops_on: bullet.pops_on, created_at: bullet.created_at, id: bullet.id
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

    def last_day_page(size: PAGE_SIZE)
      by_day.last(size)
    end

    def day_page_before(bullet, size: PAGE_SIZE)
      earlier_day_than(bullet).last_day_page(size: size)
    end
  end
end
