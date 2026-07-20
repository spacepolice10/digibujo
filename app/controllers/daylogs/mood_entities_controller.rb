# frozen_string_literal: true

module Daylogs
  class MoodEntitiesController < ApplicationController
    before_action :set_daylog

    def create
      entity = @daylog.mood_entities.find_or_initialize_by(date: mood_date)
      entity.mood = params.require(:mood)
      entity.save!
      redirect_after_mood
    end

    def destroy
      entity = @daylog.mood_entities.find_by!(date: mood_date)
      entity.destroy!
      redirect_after_mood
    end

    private

    def set_daylog
      @daylog = Current.user.daylog
      raise ActiveRecord::RecordNotFound unless @daylog
    end

    def mood_date
      Date.iso8601(params.require(:date).to_s)
    end

    def redirect_after_mood
      redirect_back fallback_location: daylog_path(date: mood_date.iso8601)
    end
  end
end
