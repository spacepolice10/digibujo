# frozen_string_literal: true

class BulletsController < ApplicationController
  before_action :set_bullet, only: %i[show edit update destroy]

  def new
    @bullet = Current.user.bullets.build(
      pops_on: params[:pops_on],
      bucket_id: params[:bucket_id]
    )
    type_name = params[:bulletable_type].presence || 'Task'
    @bullet.bulletable_type = type_name
    @bullet.bulletable = type_name.constantize.new
    @composer_frame_id = params[:composer_frame_id]
    @render_context = params[:render_context]
    @monthly_bucket_id = params[:monthly_bucket_id]
    @default_project_id = params[:default_project_id]
    @default_person_id = params[:default_person_id]
  end

  def create
    @render_context = params.dig(:bullet, :render_context)
    @monthly_bucket_id = params.dig(:bullet, :monthly_bucket_id)
    @composer_frame_id = params[:composer_frame_id]
    @bullet = create_bullet_from
    @bullet.pending_attachment_count = Array(params.dig(:bullet, :attachments)).compact_blank.size
    if @bullet.save
      attach_pending_files!(@bullet)
      update_bulletable!(@bullet)
      finalize_bullet_content!(@bullet)
      @bullet.reload
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
    if @bullet.update(bullet_params.except(:attachments, :bulletable_attributes))
      attach_pending_files!(@bullet)
      update_bulletable!(@bullet)
      finalize_bullet_content!(@bullet)
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
      :body,
      :rich_body,
      :pops_on,
      :bulletable_type,
      :bucket_id,
      attachments: [],
      bulletable_attributes: %i[mood awaits_research idea]
    )
  end

  def create_bullet_from
    permitted = bullet_params
    type_name = permitted[:bulletable_type].presence || 'Task'
    attributes = permitted.except(:bulletable_type, :attachments, :bulletable_attributes)
    Current.user.bullets.new(attributes.merge(bulletable: type_name.constantize.new))
  end

  def attach_pending_files!(bullet)
    signed_ids = Array(params.dig(:bullet, :attachments)).compact_blank
    return if signed_ids.empty?

    bullet.attachments.attach(signed_ids)
  end

  def update_bulletable!(bullet)
    attrs = params.dig(:bullet, :bulletable_attributes)
    return unless attrs.present? && bullet.bulletable.is_a?(Note)

    bullet.bulletable.update!(attrs.permit(:mood, :awaits_research, :idea))
  end

  def finalize_bullet_content!(bullet)
    body_record = ActionText::RichText.find_by(record: bullet, name: 'body')
    bullet.apply_project_tags_from_content!(rich_text_record: body_record) if body_record
    bullet.apply_people_tags_from_content!(rich_text_record: body_record) if body_record
    bullet.sanitize_rich_body_tag_attachables!
    purge_blank_rich_body!(bullet)
  end

  def purge_blank_rich_body!(bullet)
    return unless bullet.rich_body.blank?

    ActionText::RichText.find_by(record: bullet, name: 'rich_body')&.destroy
  end

  def render_create_turbo_stream
    template = if @render_context.present? && create_turbo_stream_variant?(@render_context)
                 "bullets/create.#{@render_context}"
               else
                 'bullets/create'
               end
    render template
  end

  def create_turbo_stream_variant?(render_context)
    lookup_context.exists?("bullets/create.#{render_context}", [], false, [], formats: [:turbo_stream])
  end

  def render_invalid_create
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
    )
  end
end
