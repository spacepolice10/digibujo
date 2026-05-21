# frozen_string_literal: true

class Bullets::PopsController < ApplicationController
  before_action :set_bullet

  def create
    @bullet.pop!(pops_on: pops_on_param)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(@bullet, partial: @bullet.to_partial_path, locals: bullet_partial_locals)
      end
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  end

  def destroy
    @bullet.unpop!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(@bullet, partial: @bullet.to_partial_path, locals: bullet_partial_locals)
      end
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  end

  def postpone_next_day
    @bullet.postpone_next_day!(from: pop_anchor_date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(@bullet, partial: @bullet.to_partial_path, locals: bullet_partial_locals)
      end
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  end

  def postpone_next_week
    @bullet.postpone_next_week!(from: pop_anchor_date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(@bullet, partial: @bullet.to_partial_path, locals: bullet_partial_locals)
      end
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end

  def pops_on_param
    Date.iso8601(params.require(:pops_on).to_s)
  end

  def pop_anchor_date
    return nil if params[:display_on].blank?

    Date.iso8601(params[:display_on].to_s)
  rescue ArgumentError
    nil
  end

  def bullet_partial_locals
    { @bullet.bulletable_type.downcase.to_sym => @bullet }
  end
end
