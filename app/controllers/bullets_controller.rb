# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    @bullet = Current.user.bullets.build(
      pops_on: params[:pops_on],
      bucket_id: params[:bucket_id]
    )
    @bulletable_type = params[:bulletable_type].presence || "Note"
    @composer_frame_id = params[:composer_frame_id]
    @render_context = params[:render_context]
    @monthlylog_id = params[:monthlylog_id]
  end

  def create
    @render_context = params.dig(:bullet, :render_context)
    @monthlylog_id = params.dig(:bullet, :monthlylog_id)
    @composer_frame_id = params[:composer_frame_id]
    @bullet = create_bullet_from
    if @bullet.save
      respond_to do |format|
        format.turbo_stream { render_create_turbo_stream }
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_invalid_create }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params)
      BulletActivityRecorder.record_updated!(bullet: @bullet)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@bullet) }
      end
    else
      render :edit, status: :unprocessable_entity
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
      :content,
      :pops_on,
      :bulletable_type,
      :bucket_id,
      bulletable_attributes: {}
    )
  end

  def create_bullet_from
    permitted = bullet_params
    type_name = permitted[:bulletable_type].to_s
    attributes = permitted.except(:bulletable_type, "bulletable_type")
    Current.user.bullets.new(attributes.merge(bulletable: type_name.constantize.new))
  end

  def render_create_turbo_stream
    template = if @render_context.present? && create_turbo_stream_variant?(@render_context)
      "bullets/create.#{@render_context}"
    else
      "bullets/create"
    end
    render template
  end

  def create_turbo_stream_variant?(render_context)
    lookup_context.exists?("bullets/create.#{render_context}", [], false, [], formats: [:turbo_stream])
  end

  def editor_attributes_for(bullet)
    {
      pops_on: bullet.pops_on,
      bucket_id: bullet.bucket_id
    }
  end

  def render_invalid_create
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
    )
  end
end
