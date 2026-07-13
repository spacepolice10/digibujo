# frozen_string_literal: true

module Bullets
  class ArchivesController < ApplicationController
    include PrepareBullets

    before_action :prepare_bullets

    def create
      Bullet.transaction do
        @bullets.lock.find_each(&:archive!)
      end
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

    def destroy
      Bullet.transaction do
        @bullets.lock.find_each(&:unarchive!)
      end
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: daylog_path }
      end
    rescue ActiveRecord::RecordInvalid => e
      @failed_bullet = e.record
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path,
                        alert: e.record.errors.full_messages.to_sentence
        end
      end
    end
  end
end
