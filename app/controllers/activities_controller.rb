# frozen_string_literal: true

class ActivitiesController < ApplicationController
  RECENT_LIMIT = 6

  SUBJECT_ASSOCIATIONS = { 'Bullet' => :bullets, 'Bucket' => :buckets }.freeze

  def index
    scope = scoped_activities
    return if performed?

    @activities = set_page_and_extract_portion_from(scope, per_page: [30, 50, 100])
  end

  def rail
    @activities = recent_activities
  end

  private

  def scoped_activities
    activities = Current.user.activities.includes(:subject).order(created_at: :desc)

    if subject_scope?
      @subject = find_subject
      return if performed?

      activities.where(subject: @subject)
    else
      activities
    end
  end

  def recent_activities
    Current.user.activities
           .includes(:subject)
           .order(created_at: :desc)
           .limit(RECENT_LIMIT)
  end

  def subject_scope?
    params[:subject_type].present? && params[:subject_id].present?
  end

  def find_subject
    association = SUBJECT_ASSOCIATIONS[params[:subject_type]]
    unless association
      head :not_found
      return
    end

    Current.user.public_send(association).find(params[:subject_id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
    nil
  end
end
