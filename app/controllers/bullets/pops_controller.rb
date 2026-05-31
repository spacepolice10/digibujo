# frozen_string_literal: true

class Bullets::PopsController < ApplicationController
  MAX_BULK_BULLET_IDS = 200

  before_action :set_bullets, only: %i[new create destroy]

  def new
    @pop_asap = Date.current
    @pop_tomorrow = Date.current + 1.day
    @pop_next_monday = Date.current.next_occurring(:monday)
  end

  def create
    pops_on = pops_on_param
    @pops_previous_by_bullet_id = {}
    Bullet.transaction do
      @bullets.lock.find_each do |bullet|
        @pops_previous_by_bullet_id[bullet.id] = bullet.pops_on
        bullet.pop!(pops_on: pops_on)
      end
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
  rescue ArgumentError
    @failed_bullet = @bullets.first
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path_to(daylog_redirect_date), alert: "Invalid date"
      end
    end
  end

  def destroy
    previous_pops_on = previous_pops_on_param
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.unpop!(previous_pops_on: previous_pops_on) }
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
  rescue ArgumentError
    @failed_bullet = @bullets.first
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path_to(daylog_redirect_date), alert: "Invalid date"
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

  def pops_on_param
    Date.iso8601(params.require(:pops_on).to_s)
  end

  def previous_pops_on_param
    value = params[:pops_on]
    return nil if value.blank?

    value.is_a?(Date) ? value : Date.iso8601(value.to_s)
  end
end
