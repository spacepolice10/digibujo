# frozen_string_literal: true

class Bullets::CollectsController < ApplicationController
  include BulletIntentResponses

  before_action :set_bullet

  def create
    @bullet.collect!(bucket_id: params[:bucket_id])
    respond_with_bullet_intent
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end
end
