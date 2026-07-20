# frozen_string_literal: true

module Monthlylogs
  class MoodEntriesController < ApplicationController
    before_action :set_monthlylog

    def create
      entry = @monthlylog.mood_entries.find_or_initialize_by(date: mood_date)
      entry.mood = params.require(:mood)
      entry.save!
      redirect_to monthlylog_path(@monthlylog)
    end

    def destroy
      entry = @monthlylog.mood_entries.find_by!(date: mood_date)
      entry.destroy!
      redirect_to monthlylog_path(@monthlylog)
    end

    private

    def set_monthlylog
      @monthlylog = Current.user.monthlylogs.find(params[:monthlylog_id])
      raise ActiveRecord::RecordNotFound unless @monthlylog.mood_tracker_enabled?
    end

    def mood_date
      Date.iso8601(params.require(:date).to_s)
    end
  end
end
