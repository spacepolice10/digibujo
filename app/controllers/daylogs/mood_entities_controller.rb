# frozen_string_literal: true

module Daylogs
  class MoodEntitiesController < ApplicationController
    before_action :set_daylog

    def create
      @daylog.pick_mood(date: mood_date, mood: params.require(:mood))
      redirect_to daylog_path(date: mood_date.iso8601)
    end

    def destroy
      @daylog.remove_mood(date: mood_date)
      redirect_to daylog_path(date: mood_date.iso8601)
    end

    private

    def set_daylog
      @daylog = Current.user.daylog
      raise ActiveRecord::RecordNotFound unless @daylog
    end

    def mood_date
      Date.iso8601(params.require(:date).to_s)
    end
  end
end
