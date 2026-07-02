# frozen_string_literal: true

class ActivitiesController < ApplicationController
  def index
    activities = Current.user.activities.includes(:subject).order(created_at: :desc)
    @activities = set_page_and_extract_portion_from(activities, per_page: [30, 50, 100])
  end

  def compact
    @activities = Current.user.activities
                         .includes(:subject)
                         .order(created_at: :desc)
                         .limit(6)
  end
end
