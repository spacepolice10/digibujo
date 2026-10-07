# frozen_string_literal: true

module Bullets
  class CollectsController < ApplicationController
    include PrepareBullets, ReturnToPath

    before_action :prepare_bullets
    return_to_from :param, :referer, only: :new

    def new
      @collects_q = params[:q].to_s.strip.presence
      @collections = Current.user.collections
        .matching_name(params[:q])
        .order(:name)
        .limit(10)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def create
      collection_id = params.require(:collection_id)
      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.collect!(collection_id: collection_id) }
      end
      @bullets.each(&:reload)
      @collection = Current.user.collections.find(collection_id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end
  end
end
