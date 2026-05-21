# frozen_string_literal: true

class Bullets::CollectsController < ApplicationController
  before_action :set_bullet

  def create
    @bullet.collect!(bucket_id: params.require(:bucket_id))

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(@bullet, partial: @bullet.to_partial_path, locals: bullet_partial_locals)
      end
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  end

  def destroy
    @bullet.uncollect!

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

  def bullet_partial_locals
    { @bullet.bulletable_type.downcase.to_sym => @bullet }
  end
end
