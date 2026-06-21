# frozen_string_literal: true

class ActivitiesController < ApplicationController
  ALLOWED_SUBJECT_TYPES = %w[Bullet Bucket].freeze

  def index
    if params[:subject_type].present? && params[:subject_id].present?
      subject = find_subject(params[:subject_type], params[:subject_id])
      return head :not_found unless subject

      @activities = subject.activities.order(created_at: :desc)
    else
      @activities = Current.user.activities.order(created_at: :desc)
    end
  end

  private

  def find_subject(subject_type, subject_id)
    return unless ALLOWED_SUBJECT_TYPES.include?(subject_type)

    case subject_type
    when "Bullet"
      Current.user.bullets.find_by(id: subject_id)
    when "Bucket"
      Current.user.buckets.find_by(id: subject_id)
    end
  end
end
