class Bullets::PublishesController < ApplicationController
  before_action :set_bullet

  def update
    if @bullet.published?
      @bullet.unpublish!
    else
      @bullet.publish!
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @bullet }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end
end
