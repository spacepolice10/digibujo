# frozen_string_literal: true

module Trackers
  class StopsController < ApplicationController
    def create
      tracker = Current.user.trackers.find(params[:tracker_id])
      tracker.stop!
      redirect_to tracker_path(tracker), notice: 'Tracker stopped'
    end
  end
end
