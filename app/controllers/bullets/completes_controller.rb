class Bullets::CompletesController < ApplicationController
  before_action :set_bullet

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


end
