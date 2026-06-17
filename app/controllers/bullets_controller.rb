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
    @default_project_id = params[:default_project_id]
    @default_person_id = params[:default_person_id]
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
        format.turbo_stream { render_invalid_create }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def show; end

  def update
    if @bullet.update(bullet_params.except(:bulletable_attributes))
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
      :body, :rich_body, :pops_on, :bulletable_type, :bucket_id, :indented,
      attachments: [],
      bulletable_attributes: %i[mood awaits_research idea]
    )
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

  def render_invalid_create
    render turbo_stream: turbo_stream.update(
      'toasts',
      partial: 'shared/toasts',
      locals: { type: 'errmsg', messages: @bullet.errors.full_messages }
    )
  end
end
