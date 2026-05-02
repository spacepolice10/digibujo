class Triage::PostponesController < ApplicationController
  before_action :set_bullet

  def create
    @bullet.update!(
      scheduled_on: postpone_date,
      triaged_at: @bullet.triaged_at || Time.current
    )

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to triage_path(date: selected_date_param.iso8601) }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.triage_on_date(selected_date_param).find(params[:bullet_bullet_id] || params[:bullet_id])
  end

  def postpone_date
    selected_date_param + 1.day
  end

  def selected_date_param
    return Date.current if params[:date].blank?

    Date.iso8601(params[:date])
  rescue ArgumentError
    Date.current
  end
end
