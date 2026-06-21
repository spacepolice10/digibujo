# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    @bullet = BulletCreator.new(Current.user, new_bullet_params.to_h).build.bullet
  end

  def create
    result = BulletCreator.new(Current.user, bullet_params).call
    @bullet = result.bullet

    if result.success?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_validation_toast(@bullet) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params.except(:bulletable_attributes))
      BulletContentFinalizer.call(@bullet, bulletable_attributes: params.dig(:bullet, :bulletable_attributes))
      @bullet.record_activity!("updated")
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_validation_toast(@bullet) }
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
    params.require(:bullet).permit(
      :body, :rich_body, :pops_on, :bulletable_type, :bucket_id, :composer_id, :indented,
      attachments: [],
      bulletable_attributes: %i[mood awaits_research idea]
    )
  end

  def new_bullet_params
    params.permit(:pops_on, :bucket_id, :bulletable_type, :composer_id)
  end

  def render_validation_toast(record)
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: record.errors.full_messages }
    ), status: :unprocessable_entity
  end
end
