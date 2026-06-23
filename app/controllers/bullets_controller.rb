# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    type_name = new_bullet_params[:bulletable_type].presence || Bullet::Composer.default_type
    @bullet = Current.user.bullets.new(
      new_bullet_params.to_h.merge(bulletable_type: type_name, bulletable_attributes: {})
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
        format.turbo_stream { render_validation_toast(@bullet) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params)
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
      :body, :rich_body, :pops_on, :bulletable_type, :bucket_id, :indented,
      attachments: [],
      bulletable_attributes: permitted_bullet_attributes
    ).then { |p| ensure_bulletable_defaults!(p) }
  end

  def new_bullet_params
    params.permit(:pops_on, :bucket_id, :bulletable_type).then { |p| ensure_bulletable_defaults!(p) }
  end

  def render_validation_toast(record)
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: record.errors.full_messages }
    ), status: :unprocessable_entity
  end
end
