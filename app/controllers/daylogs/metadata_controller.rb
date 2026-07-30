# frozen_string_literal: true

module Daylogs
  class MetadataController < ApplicationController
    def show
      @date = Date.iso8601(params.require(:date).to_s)
      calendar_date = Current.user.calendar_dates.includes(:mood_entity, :picture).find_or_create_by!(date: @date)
      @mood_entity = calendar_date.mood_entity
      @picture = calendar_date.picture if calendar_date.picture&.picture&.attached?
    end
  end
end
