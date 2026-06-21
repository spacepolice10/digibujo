# frozen_string_literal: true

module Bullets
  class CollectsController < ApplicationController
    include PrepareBullets, UserCollections, DaylogRedirects

    before_action :prepare_bullets

    def new
      @return_to = permitted_return_to(params[:return_to]) || permitted_return_to(request.referer)
      @collects_q = sanitized_query
      @collections = user_collections
      @collections = @collections.where('buckets.name LIKE ?', "#{@collects_q}%") if @collects_q.present?
      @collections = @collections.limit(5) if review_collect_picker_request? && @collects_q.blank?
    end

    def create
      bucket_id = params.require(:bucket_id)
      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.collect!(bucket_id: bucket_id) }
      end
      @bullets.each(&:reload)
      return head :no_content if review_collect_drop_request?

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

    def review_collect_drop_request?
      request.headers['X-Requested-With'] == 'review-collect-drop'
    end

    def review_collect_picker_request?
      params[:frame_id] == 'review_collect_picker_frame'
    end

    def permitted_return_to(url)
      return if url.blank?

      uri = URI.parse(url.to_s)
      return if uri.host.present? && uri.host != request.host

      [uri.path, uri.query].compact.join('?').presence
    rescue URI::InvalidURIError
      nil
    end
  end
end
