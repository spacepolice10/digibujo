# frozen_string_literal: true

module Bullets
  class CompletesController < ApplicationController
    include PrepareBullets, DaylogRedirects

    NON_COMPLETABLE_MESSAGE = 'Only tasks can be completed'

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
      @error_message = NON_COMPLETABLE_MESSAGE
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
                        alert: NON_COMPLETABLE_MESSAGE
        end
      end
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
      @error_message = NON_COMPLETABLE_MESSAGE
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
                        alert: NON_COMPLETABLE_MESSAGE
        end
      end
    end
  end
end
