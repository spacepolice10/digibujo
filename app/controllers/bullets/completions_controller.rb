# frozen_string_literal: true

module Bullets
  class CompletionsController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each(&:complete!)
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
      end
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each(&:uncomplete!)
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: bullets_path }
      end
    end
  end
end
