# frozen_string_literal: true

module Trackers
  class StatusesController < ApplicationController
    COMPLETION_DOM_KEYS = %w[date monthlylog].freeze

    before_action :set_tracker
    before_action :set_date
    before_action :set_dom_key

    def create
      return respond_unprocessable unless @tracker.scheduled_on?(@date)

      calendar_date = Current.user.calendar_dates.find_or_create_by!(date: @date)
      @status = @tracker.statuses.find_or_initialize_by(calendar_date: calendar_date)
      @status.completed_at = Time.current
      @status.save!

      respond_to_status
    end

    def destroy
      calendar_date = Current.user.calendar_dates.find_by!(date: @date)
      @status = @tracker.statuses.find_by(calendar_date: calendar_date)
      @status&.destroy!

      respond_to_status
    end

    private

    def set_tracker
      @tracker = Current.user.trackers.find(params[:tracker_id])
    end

    def set_date
      @date = Date.iso8601(params[:date].to_s)
    rescue ArgumentError
      head :unprocessable_entity
    end

    def respond_to_status
      @tracker = Current.user.trackers.where(id: @tracker.id).with_completions.first

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: home_path }
        format.any { head :no_content }
      end
    end

    def set_dom_key
      @dom_key = params[:dom_key].presence_in(COMPLETION_DOM_KEYS) || 'header'
    end

    def respond_unprocessable
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_back fallback_location: home_path, alert: 'Cannot mark this day' }
        format.any { head :unprocessable_entity }
      end
    end
  end
end
