# frozen_string_literal: true

class BulletsController < ApplicationController
  include BulletCreation

  before_action :set_bullet, only: %i[show edit update destroy]
  before_action :redirect_voice_edit, only: %i[edit update]

  def new
    prepare_bullet
  end

  def create
    create_bullet
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params)
      @bullet.record_activity!('updated')
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { notify(@bullet) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @bullet.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to daylog_path(date: (@bullet.pops_on || Date.current).iso8601) }
    end
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:id])
  end

  def redirect_voice_edit
    return unless @bullet.bulletable_type == "Voice"

    redirect_to bullet_path(@bullet)
  end
end
