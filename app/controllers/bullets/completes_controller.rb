# frozen_string_literal: true

module Bullets
  class CompletesController < ApplicationController
    include PrepareBullets, DaylogRedirects

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each do |bullet|
          raise ActiveRecord::RecordNotFound unless bullet.completable?

          bullet.bulletable.complete!
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to daylog_path(date: daylog_redirect_date.iso8601) }
      end
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each do |bullet|
          raise ActiveRecord::RecordNotFound unless bullet.completable?

          bullet.bulletable.uncomplete!
        end
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to daylog_path(date: daylog_redirect_date.iso8601) }
      end
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end
  end
end
