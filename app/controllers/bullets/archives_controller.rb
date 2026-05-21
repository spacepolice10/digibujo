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
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to daylog_path_to(daylog_redirect_date), alert: @bullet.errors.full_messages.to_sentence
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end
end
