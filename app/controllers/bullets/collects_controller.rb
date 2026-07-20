# frozen_string_literal: true

module Bullets
  class CollectsController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets
    before_action :set_return_to, only: :new

    def new
      @collects_q = params[:q].to_s.strip.presence
      @collections, @collections_page = collectables_page(
        Current.user.collections.merge(Bucket.active.matching_name(params[:q])).order('buckets.name')
      )

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
        format.html { redirect_back fallback_location: daylog_path }
      end
    rescue ActiveRecord::RecordInvalid => e
      @failed_bullet = e.record
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path,
                        alert: e.record.errors.full_messages.to_sentence
        end
      end
    end

    private

    def set_return_to
      @return_to = permitted_return_to(params[:return_to]) || permitted_return_to(request.referer)
    end

    def collectables_page(scope)
      page = GearedPagination::Recordset.new(scope, per_page: [8, 16, 24])
                    .page(params[:collections_page])
      [page.records, page]
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
