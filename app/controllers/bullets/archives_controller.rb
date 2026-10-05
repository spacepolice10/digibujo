# frozen_string_literal: true

module Bullets
  class ArchivesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each(&:archive!)
      end
      @bullets.each(&:reload)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each(&:unarchive!)
      end
      @bullets.each(&:reload)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_with_failed_bullet(e)
    end
  end
end
