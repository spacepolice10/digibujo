# frozen_string_literal: true

module Bullets
  class CollectsController < ApplicationController
    include PrepareBullets, UserCollections, DaylogRedirects

    before_action :prepare_bullets

    def new
      @collects_q = sanitized_query
      @collections = user_collections
      @collections = @collections.where('buckets.name LIKE ?', "#{@collects_q}%") if @collects_q.present?
    end

    def create
      bucket_id = params.require(:bucket_id)
      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.collect!(bucket_id: bucket_id) }
      end
      @bullets.each(&:reload)
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
      @bullets.each(&:reload)
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

    def sanitized_query
      @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
    end
  end
end
