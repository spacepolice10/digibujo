# frozen_string_literal: true

class ActivitiesController < ApplicationController
  def index
    @activities = Current.user.bullet_activities.order(created_at: :desc)
  end
end
