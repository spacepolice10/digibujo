# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    preview = Bullet::Params.preview(params)
    @bullet = Current.user.bullets.new(preview.except(:bulletable_attributes))
    @composer_attributes = composer_attributes_from(preview)
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
        format.turbo_stream { notify(@bullet) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  rescue Bullet::Params::TypeRequired
    respond_to do |format|
      format.turbo_stream { notify_type_required }
      format.html do
        redirect_back fallback_location: daylog_path, alert: 'Bullet type is required'
      end
    end
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

  def bullet_params
    Bullet::Params.permit(params, bullet: @bullet)
  end

  def composer_attributes_from(preview)
    {
      pops_on: preview[:pops_on],
      bucket_id: preview[:bucket_id],
      composer_id: params[:composer_id].presence || 'bullet_composer'
    }.compact
  end

  def notify_type_required
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: ['Bullet type is required'] }
    ), status: :unprocessable_entity
  end

  def notify(record)
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: record.errors.full_messages }
    ), status: :unprocessable_entity
  end
end
