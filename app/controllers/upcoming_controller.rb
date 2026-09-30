# frozen_string_literal: true

# Bullets scheduled for a day that has not started yet. They join the timeline
# on their day.
class UpcomingController < ApplicationController
  LIMIT = 500

  def show
    @bullets = Current.user.timeline.upcoming.by_day.includes(:bulletable, :rich_text_body).limit(LIMIT)
    @bullets_by_day = @bullets.group_by(&:pops_on)
  end
end
