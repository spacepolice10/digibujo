# frozen_string_literal: true

class Bullets::CollectsController < ApplicationController
  include PrepareBullets

  before_action :prepare_bullets

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
      format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
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
      format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  private

  def collect_bucket_id
    return params.require(:bucket_id) if params[:project_id].blank?

    Current.user.projects.find(params.require(:project_id)).bucket.id
  end

  def sanitized_query
    @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end
end
