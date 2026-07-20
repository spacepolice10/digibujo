# frozen_string_literal: true

module Daylogs
  class PicturesController < ApplicationController
    before_action :set_daylog

    def create
      picture = @daylog.pictures.find_or_initialize_by(date: picture_date)
      picture.picture.attach(params.require(:picture))
      picture.save!
      redirect_to daylog_path(date: picture_date.iso8601)
    end

    def destroy
      @daylog.remove_picture(date: picture_date)
      redirect_to daylog_path(date: picture_date.iso8601)
    end

    private

    def set_daylog
      @daylog = Current.user.daylog
      raise ActiveRecord::RecordNotFound unless @daylog
    end

    def picture_date
      Date.iso8601(params.require(:date).to_s)
    end
  end
end
