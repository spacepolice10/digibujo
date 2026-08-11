# frozen_string_literal: true

class DaylogsController < ApplicationController
  def show
    @daylog = Current.user.daylog
    @selected_date = daylog_date_from_params
    return unless @daylog

    @bullets = @daylog.bullets.where(pops_on: @selected_date).active.last_page
    @more_bullets = @bullets.size == Bullet::Pageable::PAGE_SIZE

    @pending_bullets = current_user.bujo.current_pending.bullets.includes(:bulletable)
    @monthlylog_bullets = current_user.bujo.current_monthlylog.bullets.where(pops_on: @selected_date).includes(:bulletable)
    @bullets_to_triage = @monthlylog_bullets + @pending_bullets
    @monthlylog_number = @monthlylog_bullets.count
    @yesterdays_number = @daylog.bullets.where(pops_on: @selected_date - 1.day).count
    @monthlylog_tasks_number = @monthlylog_bullets.count { |bullet| bullet.bulletable_type == 'Task' }
    @monthlylog_note_number = @monthlylog_bullets.count { |bullet| bullet.bulletable_type == 'Note' }
    @monthlylog_events_number = @monthlylog_bullets.count { |bullet| bullet.bulletable_type == 'Event' }
    @task_number = @bullets_to_triage.count { |bullet| bullet.bulletable_type == 'Task' }
    @note_number = @bullets_to_triage.count { |bullet| bullet.bulletable_type == 'Note' }
    @events_number = @bullets_to_triage.count { |bullet| bullet.bulletable_type == 'Event' }

    Rails.logger.info("Bullets: #{@bullets.inspect}")
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
