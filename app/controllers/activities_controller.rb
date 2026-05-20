# frozen_string_literal: true

# HTML index of `BulletActivity` for the current user (all bullets, or +bullet_id+ filter).
class ActivitiesController < ApplicationController
  def index
    scope = Current.user.bullet_activities.order(created_at: :desc)
    if params[:bullet_id].present?
      @bullet = Current.user.bullets.find(params[:bullet_id])
      scope = scope.where(bullet_id: @bullet.id)
    end

    records = set_page_and_extract_portion_from(scope, per_page: [15, 30, 50])
    @bullets_by_id = preload_bullets_for_activity_records(records)
  end

  private

  def preload_bullets_for_activity_records(records)
    ids = records.map(&:bullet_id).uniq
    Current.user.bullets.includes(:bulletable).where(id: ids).index_by(&:id)
  end
end
