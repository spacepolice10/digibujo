# frozen_string_literal: true

class Bullets::SchedulesController < ApplicationController
  include BulletIntentResponses

  before_action :set_bullet

  def create
    @bullet.schedule!(scheduled_on: params[:scheduled_on])
    assign_bucket_if_present_after_schedule
    respond_with_bullet_intent
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end

  def assign_bucket_if_present_after_schedule
    return if params[:bucket_id].blank?

    @bullet.collect!(bucket_id: params[:bucket_id])
  end
end
