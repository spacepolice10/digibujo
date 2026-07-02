# frozen_string_literal: true

class ActivitiesController < ApplicationController
  SUBJECT_ASSOCIATIONS = { 'Bullet' => :bullets, 'Bucket' => :buckets }.freeze

  def index
    activities = Current.user.activities.includes(:subject).order(created_at: :desc)
    return if performed?

    @activities = set_page_and_extract_portion_from(activities, per_page: [30, 50, 100])
  end

  def compact
    @activities = Current.user.activities
                         .includes(:subject)
                         .order(created_at: :desc)
                         .limit(6)
  end
end
