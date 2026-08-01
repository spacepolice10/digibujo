# frozen_string_literal: true

class TriageController < ApplicationController
  def show
    @pending = Pending.provision!(Current.user)
    inbox = Pending.pending_of(Current.user)
    monthlylog = Current.user.monthlylogs.covering(Date.current).take
    inbox = inbox.or(monthlylog.bullets.active.where(pops_on: Date.current)) if monthlylog

    @bullets = set_page_and_extract_portion_from(
      inbox,
      per_page: [15, 30, 50, 100]
    )
  end

  def number
    pending = Pending.pending_number_of(Current.user)
    monthlylog = Current.user.monthlylogs.covering(Date.current).take
    today = monthlylog ? monthlylog.bullets.active.where(pops_on: Date.current).count : 0

    render json: { number: pending + today }
  end
end
