# frozen_string_literal: true

module Daylogs
  # Renders the daylog migration workspace and its inline preview states.
  class TriageController < ApplicationController
    def show
      @daylog = Current.user.daylog
      return head :not_found unless @daylog

      @selected_date = Date.current
      @triage = Daylog::Triage.new(Current.user, date: @selected_date)
      @today_bullets = @daylog.bullets.active.where(pops_on: @selected_date).includes(:bulletable).chronologically

      render :preview, layout: false if params[:preview].present?
    end
  end
end
