# frozen_string_literal: true

class Bullets::ArchivesController < ApplicationController
  MAX_BULK_BULLET_IDS = 200

  before_action :set_bullets

  def create
    Bullet.transaction do
      @bullets.lock.find_each(&:archive!)
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: daylog_path_to(daylog_redirect_date) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path_to(daylog_redirect_date),
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
      format.html { redirect_back fallback_location: daylog_path_to(daylog_redirect_date) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path_to(daylog_redirect_date),
                      alert: e.record.errors.full_messages.to_sentence
      end
    end
  end

  private

  def set_bullets
    ids = params.fetch(:bullet_ids, "").split(",").map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
    raise ActiveRecord::RecordNotFound if ids.empty? || ids.size > MAX_BULK_BULLET_IDS

    @bullets = Current.user.bullets.where(id: ids).order(:id)
    raise ActiveRecord::RecordNotFound if @bullets.count != ids.size
  end
end
