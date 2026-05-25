# frozen_string_literal: true

class Bullets::PopsController < ApplicationController
  before_action :set_bullet

  def create
    @previous_pops_on = @bullet.pops_on
    @bullet.pop!(pops_on: pops_on_param)
    respond_to do |format|
      format.turbo_stream 
      format.html { redirect_back fallback_location: daylog_path_to(daylog_redirect_date) }
    end
  end

  def destroy
    @bullet.unpop!(previous_pops_on: previous_pops_on_param)

    respond_to do |format|
      format.turbo_stream 
      format.html { redirect_back fallback_location: daylog_path_to(daylog_redirect_date) }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end

  def pops_on_param
    Date.iso8601(params.require(:pops_on).to_s)
  end

  def previous_pops_on_param
    params.require(:pops_on)
  end

  def bullet_partial_locals
    { @bullet.bulletable_type.downcase.to_sym => @bullet }
  end
end
