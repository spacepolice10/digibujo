# frozen_string_literal: true

module Bullet::Pageable
  extend ActiveSupport::Concern

  PAGE_SIZE = 20

  included do
    scope :by_date, -> { order(pops_on: :asc, created_at: :asc, id: :asc) }
    scope :by_completion_desc, -> { order(done_at: :desc, id: :desc) }

    scope :earlier_date_than, lambda { |bullet|
      where(
        'bullets.pops_on < :pops_on ' \
        'OR (bullets.pops_on = :pops_on AND bullets.created_at < :created_at) ' \
        'OR (bullets.pops_on = :pops_on AND bullets.created_at = :created_at AND bullets.id < :id)',
        pops_on: bullet.pops_on, created_at: bullet.created_at, id: bullet.id
      )
    }

    scope :completed_before, lambda { |bullet|
      where(
        'bullets.done_at < :done_at ' \
        'OR (bullets.done_at = :done_at AND bullets.id < :id)',
        done_at: bullet.done_at, id: bullet.id
      )
    }
  end

  class_methods do
    # `last` flips the order in SQL and hands the array back in reading order,
    # so the newest page costs one query and no OFFSET.
    def last_page(size: PAGE_SIZE)
      by_date.last(size)
    end

    def prev_page(bullet, size: PAGE_SIZE)
      earlier_date_than(bullet).last_page(size: size)
    end

    # Completed feed is newest-first by completion time, so the first page is
    # a plain DESC limit and older pages filter on the (done_at, id) cursor.
    def last_completed_page(size: PAGE_SIZE)
      by_completion_desc.limit(size).to_a
    end

    def prev_completed_page(bullet, size: PAGE_SIZE)
      completed_before(bullet).by_completion_desc.limit(size).to_a
    end
  end
end
