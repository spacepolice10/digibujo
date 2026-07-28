# frozen_string_literal: true

module Daylogs
  class MoodEntitiesController < ApplicationController
    before_action :set_daylog
    before_action :set_mood_date

    def create
      @mood_entity = @daylog.pick_mood(date: @date, mood: params.require(:mood))
      respond_to_mood
    end

    def destroy
      @daylog.remove_mood(date: @date)
      @mood_entity = nil
      respond_to_mood
    end

    private

    def set_daylog
      @daylog = Current.user.daylog
      raise ActiveRecord::RecordNotFound unless @daylog
    end

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
