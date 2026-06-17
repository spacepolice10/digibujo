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
      render :new, status: :unprocessable_entity
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
      :body, :rich_body, :pops_on, :bulletable_type, :bucket_id, :composer_id, :indented,
      attachments: [],
      bulletable_attributes: %i[mood awaits_research idea]
    )
  end

  def new_bullet_params
    params.permit(:pops_on, :bucket_id, :bulletable_type, :composer_id)
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


end
