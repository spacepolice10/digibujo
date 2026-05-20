class Bullets::PinsController < ApplicationController
  before_action :set_bullet

  def update
    if @bullet.update(pinned: !@bullet.pinned?)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullets_path }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_entity }
        format.html { redirect_to bullets_path, alert: @bullet.errors.full_messages.to_sentence }
      end
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end
end
