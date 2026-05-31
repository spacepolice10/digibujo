# frozen_string_literal: true

class Bullets::CollectsController < ApplicationController
  MAX_BULK_BULLET_IDS = 200

  before_action :set_bullets

  def new
    @q = sanitized_query
    @projects = Current.user.projects.includes(:bucket)
    @projects = @projects.where("buckets.name LIKE ?", "#{@q}%") if @q.present?
  end

  def create
    bucket_id = collect_bucket_id
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.collect!(bucket_id: bucket_id) }
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: daylog_path_to(daylog_redirect_date) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path_to(daylog_redirect_date),
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  def destroy
    Bullet.transaction do
      @bullets.lock.find_each(&:uncollect!)
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: daylog_path_to(daylog_redirect_date) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path_to(daylog_redirect_date),
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  private

  def set_bullets
    ids = params.fetch(:bullet_ids, "").split(",").map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
    raise ActiveRecord::RecordNotFound if ids.empty? || ids.size > MAX_BULK_BULLET_IDS

    @bullets = Current.user.bullets.where(id: ids).order(:id)
    raise ActiveRecord::RecordNotFound if @bullets.count != ids.size
  end

  def collect_bucket_id
    return params.require(:bucket_id) if params[:project_id].blank?

    Current.user.projects.find(params.require(:project_id)).bucket.id
  end

  def sanitized_query
    @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end
end
