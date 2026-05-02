class Bullets::CompletesController < ApplicationController
  before_action :set_bullet
  before_action :set_render_partial

  def create
    @bullet.complete!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bullets_path }
    end
  end

  def destroy
    @bullet.uncomplete!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bullets_path }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end

  def set_render_partial
    @bullet_partial = request.referer.to_s.include?("/triage") ? "triage/bullet" : "bullets/bullet"
  end
end
