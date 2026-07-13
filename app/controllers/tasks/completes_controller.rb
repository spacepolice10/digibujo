# frozen_string_literal: true

module Tasks
  class CompletesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each do |bullet|
          bullet.bulletable.complete!
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to daylog_path }
      end
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each do |bullet|
          bullet.bulletable.uncomplete!
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to daylog_path }
      end
    end
  end
end
