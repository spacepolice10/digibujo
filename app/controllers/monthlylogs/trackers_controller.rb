# frozen_string_literal: true

module Monthlylogs
  class TrackersController < ApplicationController
    before_action :set_monthlylog

    def new
      @tracker = @monthlylog.trackers.new(schedule: Tracker::DEFAULT_SCHEDULE.dup)
    end

    def create
      @tracker = @monthlylog.trackers.build(tracker_attributes)
      if @tracker.save
        redirect_to monthlylog_path(@monthlylog), notice: 'Tracker created'
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_monthlylog
      @monthlylog = Current.user.monthlylogs.find(params[:monthlylog_id])
    end

    def tracker_attributes
      permitted = params.require(:tracker).permit(
        :name, :colour, :icon, schedule_days: []
      )
      attrs = {
        name: permitted[:name],
        schedule: {
          'days' => Array(permitted[:schedule_days]).reject(&:blank?).map(&:to_i).uniq.sort.presence ||
            Tracker::DEFAULT_SCHEDULE['days']
        }
      }
      attrs[:colour] = permitted[:colour].presence if permitted.key?(:colour)
      attrs[:icon] = permitted[:icon].presence if permitted.key?(:icon)
      attrs
    end
  end
end
