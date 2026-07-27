# frozen_string_literal: true

class DaylogsController < ApplicationController
  def show
    @selected_date = daylog_date_from_params or return
    @daylog = Current.user.daylog
    return unless @daylog

    @daylog_bucket = @daylog.bucket
    # Chat order: newest page first on screen, older pages pulled in from the top
    # by Daylogs::BulletsController.
    @bullets = @daylog.bullets.where(pops_on: @selected_date).active.last_page
    @more_bullets = @bullets.size == Bullet::Pageable::PAGE_SIZE
    @mood_entity = @daylog.mood_entities.find_by(date: @selected_date)
    @picture = @daylog.pictures.find_by(date: @selected_date)
  end

  def create
    Daylog.provision!(Current.user)
    redirect_to daylog_path
  end

  private

  def daylog_date_from_params
    if params[:date].present?
      Date.iso8601(params[:date].to_s)
    else
      Date.current
    end
  rescue ArgumentError
    head :not_found
    nil
  end
end
