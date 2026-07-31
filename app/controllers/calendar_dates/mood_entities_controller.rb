# frozen_string_literal: true

module CalendarDates
  class MoodEntitiesController < ApplicationController
    before_action :set_mood_date

    def create
      calendar_date = Current.user.calendar_dates.find_or_create_by!(date: @date)
      @mood_entity = calendar_date.pick_mood(params.require(:mood))
      respond_to_mood
    end

    private

    def set_mood_date
      @date = Date.iso8601(params.require(:date).to_s)
    end

    def respond_to_mood
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: daylog_path(date: @date.iso8601) }
      end
    end
  end
end
