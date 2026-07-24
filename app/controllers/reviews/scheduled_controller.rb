# frozen_string_literal: true

module Reviews
  class ScheduledController < ApplicationController
    def show
      @calendar_days = (Date.current..(Date.current + 6.days)).to_a
      @calendar_bullets_by_date = calendar_bullets_by_date
    end

    private

    def calendar_bullets_by_date
      Current.user.bullets
             .where(pops_on: @calendar_days)
             .active
             .order(created_at: :asc)
             .includes(:bulletable)
             .group_by(&:pops_on)
    end
  end
end
