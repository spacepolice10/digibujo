# frozen_string_literal: true

module Daylogs
  class PicturesController < ApplicationController
    before_action :set_daylog

    def create
      picture = @daylog.pictures.find_or_initialize_by(date: picture_date)
      picture.image.attach(params.require(:image))
      picture.save!
      redirect_after_picture
    end

    def destroy
      picture = @daylog.pictures.find_by!(date: picture_date)
      picture.destroy!
      redirect_after_picture
    end

    private

    def set_daylog
      @daylog = Current.user.daylog
      raise ActiveRecord::RecordNotFound unless @daylog
    end

    def picture_date
      Date.iso8601(params.require(:date).to_s)
    end

    def redirect_after_picture
      redirect_back fallback_location: daylog_path(date: picture_date.iso8601)
    end
  end
end
