# frozen_string_literal: true

class TriageController < ApplicationController
  before_action :ensure_turbo_frame_request, only: :show, if: :turbo_frame_request?

  def show
    @pending = Pending.provision!(Current.user)
    inbox = Pending.pending_of(Current.user)
    monthlylog = Current.user.monthlylogs.covering(Date.current).take
    inbox = inbox.or(monthlylog.bullets.active.where(pops_on: Date.current)) if monthlylog

    if pending_list_frame?
      @bullets = inbox.limit(50).to_a
      @pending_count = @bullets.size
    else
      @bullets = set_page_and_extract_portion_from(
        inbox,
        per_page: [15, 30, 50, 100]
      )
    end
  end

  def number
    pending = Pending.pending_number_of(Current.user)
    monthlylog = Current.user.monthlylogs.covering(Date.current).take
    today = monthlylog ? monthlylog.bullets.active.where(pops_on: Date.current).count : 0

    render json: { number: pending + today }
  end

  private

  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end

  def pending_list_frame?
    request.headers['Turbo-Frame'] == 'triage_list'
  end

  def ensure_turbo_frame_request
    head :not_found unless pending_list_frame?
  end
end
