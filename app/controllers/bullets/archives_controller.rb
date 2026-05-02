class Bullets::ArchivesController < ApplicationController
  before_action :set_bullet

  def update
    if @bullet.archived?
      @bullet.unarchive!
    else
      @bullet.archive!
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bullets_path }
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to bullets_path, alert: @bullet.errors.full_messages.to_sentence
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end
end
