# frozen_string_literal: true

class ActivitiesController < ApplicationController
  RECENT_LIMIT = 6

  def index
    @activities = Current.user.activities.order(created_at: :desc)
    return unless subject_filter?

    @activities = @activities.where(subject_type: params[:subject_type],
                                    subject_id: params[:subject_id])
  end

  def rail
    @activities = recent_activities
  end

  private

  SUBJECT_ASSOCIATIONS = { 'Bullet' => :bullets, 'Bucket' => :buckets }.freeze

  def recent_activities
    Current.user.activities
           .includes(:subject)
           .order(created_at: :desc)
           .limit(RECENT_LIMIT)
  end

  def subject_filter?
    params[:subject_type].present? && params[:subject_id].present?
  end
end
