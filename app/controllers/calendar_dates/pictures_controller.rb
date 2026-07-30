# frozen_string_literal: true

module CalendarDates
  class PicturesController < ApplicationController
    before_action :set_picture_date

    def show
      calendar_date = Current.user.calendar_dates.includes(:picture).find_by!(date: @date)
      @picture = calendar_date.picture
      raise ActiveRecord::RecordNotFound unless @picture&.picture&.attached?

      render layout: false
    end

    def create
      calendar_date = Current.user.calendar_dates.find_or_create_by!(date: @date)
      @picture = calendar_date.picture || calendar_date.build_picture
      @picture.picture.attach(params.require(:picture))
      @picture.save!
      respond_to_picture
    end

    def destroy
      calendar_date = Current.user.calendar_dates.find_by!(date: @date)
      calendar_date.remove_picture
      @picture = nil
      respond_to_picture
    end

    private

    def set_picture_date
      @date = Date.iso8601(params.require(:date).to_s)
    end

    def respond_to_picture
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to daylog_path(date: @date.iso8601) }
      end
    end
  end
end
