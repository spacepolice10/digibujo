# frozen_string_literal: true

class Bullets::PopsController < ApplicationController
  include PrepareBullets

  before_action :prepare_bullets, only: %i[new create destroy]

  def new
    @asap = Date.current
    @tomorrow = Date.current + 1.day
    @next_monday = Date.current.next_occurring(:monday)
  end

  def create
    pops_on = Date.iso8601(params[:pops_on].to_s)
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.pop!(pops_on: pops_on) }
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
    end
  rescue ArgumentError
    @failed_bullet = @bullets.first
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601), alert: "Invalid date"
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @failed_bullet = e.record
    render :create, status: :unprocessable_entity
  end

  def destroy
    previous_pops_on = params[:pops_on]
    Bullet.transaction do
      @bullets.lock.find_each { |bullet| bullet.unpop!(previous_pops_on: previous_pops_on) }
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
    end
  rescue ArgumentError
    @failed_bullet = @bullets.first
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601), alert: "Invalid date"
      end
    end
  end
end
