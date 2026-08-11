# frozen_string_literal: true

class TriageController < ApplicationController
  def show
    @pending_bullets = current_user.bujo.current_pending.bullets.includes(:bulletable)
    @monthlylog_bullets = current_user.bujo.current_monthlylog.bullets.where(pops_on: Date.current).includes(:bulletable)
    @yesterdays_bullets = current_user.bujo.current_daylog.bullets.where(pops_on: Date.current - 1.day).includes(:bulletable)
    @bullets_to_triage = @pending_bullets + @monthlylog_bullets + @yesterdays_bullets
    @bullets = @bullets_to_triage
  end

  def number
    pending = Pending.pending_number_of(Current.user)
    monthlylog = Current.user.monthlylogs.covering(Date.current).take
    today = monthlylog ? monthlylog.bullets.active.where(pops_on: Date.current).count : 0

    render json: { number: pending + today }
  end
end
