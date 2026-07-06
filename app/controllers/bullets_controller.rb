# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    @bullet = Current.user.bullets.new(
      bulletable_type: Bullet::Params.resolve_type(params[:bulletable_type]),
      pops_on: params[:pops_on],
      bucket_id: params[:bucket_id]
    )
  end

  def create
    @bullet = Current.user.bullets.new(bullet_params)

    if @bullet.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { notify_failure }
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

  def bullet_params
    Bullet::Params.permit(params, bullet: @bullet)
  end

  def notify_failure
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
    ), status: :unprocessable_entity
  end
end
