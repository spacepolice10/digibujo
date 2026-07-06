# frozen_string_literal: true

module Bullets
  class PopsController < ApplicationController
    include PrepareBullets, DaylogRedirects

    before_action :prepare_bullets, only: %i[new create destroy]

    def new
      @asap = Date.current
      @tomorrow = Date.current + 1.day
      @next_monday = Date.current.next_occurring(:monday)
      @next_weekends = Date.current.next_occurring(:saturday)
    end

    def create
      pops_on = Date.iso8601(params[:pops_on].to_s)
      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.pop!(pops_on: pops_on) }
      end
      @bullets.each(&:reload)
      return head :no_content if pops_drop_request?

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
      end
    rescue ArgumentError
      @failed_bullet = @bullets.first
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601), alert: 'Invalid date'
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      @failed_bullet = e.record
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
                        alert: e.record.errors.full_messages.to_sentence
        end
      end
    end

    def destroy
      previous_pops_on = params[:pops_on]
      Bullet.transaction do
        @bullets.lock.find_each { |bullet| bullet.unpop!(previous_pops_on: previous_pops_on) }
      end
      @bullets.each(&:reload)
      return head :no_content if pops_drop_request?

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601) }
      end
    rescue ArgumentError
      @failed_bullet = @bullets.first
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601), alert: 'Invalid date'
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      @failed_bullet = e.record
      respond_to do |format|
        format.turbo_stream { render :destroy, status: :unprocessable_entity }
        format.html do
          redirect_back fallback_location: daylog_path(date: daylog_redirect_date.iso8601),
                        alert: e.record.errors.full_messages.to_sentence
        end
      end
    end

    private

    def pops_drop_request?
      request.headers['X-Requested-With'].in?(%w[pops-drop review-pops-drop])
    end
  end
end
