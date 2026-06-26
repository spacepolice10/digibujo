# frozen_string_literal: true

module Tasks
  class CompletesController < ApplicationController
    include PrepareBullets, DaylogRedirects

    before_action :prepare_bullets

    def create
      ::Task.complete_bullets!(@bullets)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to daylog_path(date: daylog_redirect_date.iso8601) }
      end
    end

    def destroy
      ::Task.uncomplete_bullets!(@bullets)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to daylog_path(date: daylog_redirect_date.iso8601) }
      end
    end
  end
end
