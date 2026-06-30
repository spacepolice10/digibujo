# frozen_string_literal: true

module Bullets
  class CollectsController < ApplicationController
    include PrepareBullets, DaylogRedirects, PaginatedRecords

    before_action :prepare_bullets
    before_action :set_return_to, only: :new

    def new
      @collects_q = Collection.sanitized_name_query(params[:q])
      @collections, @collections_page = collectables_page(Current.user.active_collections, :collections_page)
      @sprints, @sprints_page = collectables_page(Current.user.active_sprints, :sprints_page)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def create
      bucket_id = params.require(:bucket_id)
      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.collect!(bucket_id: bucket_id) }
      end
      @bullets.each(&:reload)
      @bucket = Bucket.find(bucket_id)

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

    def set_return_to
      @return_to = permitted_return_to(params[:return_to]) || permitted_return_to(request.referer)
    end

    def collectables_page(scope, page_param)
      paginated_portion_from(
        scope.matching_bucket_name(@collects_q),
        page_param: page_param, per_page: [8, 16, 24]
      )
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
