# frozen_string_literal: true

class ActivitiesController < ApplicationController
  def index
    if params[:bullet_id].present?
      bullet = Current.user.bullets.find_by(id: params[:bullet_id])
      return head :not_found unless bullet

      @activities = bullet.bullet_activities.order(created_at: :desc)
    else
      @activities = Current.user.bullet_activities.order(created_at: :desc)
    end
  end
end
