# frozen_string_literal: true

class BulletCreator
  attr_reader :bullet

  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    build_bullet
    if @bullet.save
      update_bulletable!
      finalize_content!
      @bullet.reload
    end
    self
  end

  def success?
    @bullet.errors.none?
  end

  private

  def build_bullet
    type_name = @params[:bulletable_type].presence || 'Task'
    attributes = @params.except(:bulletable_type, :bulletable_attributes)
    bulletable_attrs = @params[:bulletable_attributes].presence || {}
    @bullet = @user.bullets.new(attributes.merge(bulletable: type_name.constantize.new(bulletable_attrs.to_h)))
  end

  def update_bulletable!
    attrs = @params[:bulletable_attributes]
    return unless attrs.present?
    return unless @bullet.bulletable.is_a?(Note) || @bullet.bulletable.is_a?(Title)

    permitted = if @bullet.bulletable.is_a?(Note)
                  attrs.permit(:mood, :awaits_research, :idea)
                else
                  attrs.permit(:text)
                end

    @bullet.bulletable.update!(permitted)
  end

  def finalize_content!
    body_record = ActionText::RichText.find_by(record: @bullet, name: 'body')
    @bullet.apply_project_tags_from_content!(rich_text_record: body_record) if body_record
    @bullet.apply_people_tags_from_content!(rich_text_record: body_record) if body_record
    @bullet.sanitize_rich_body_tag_attachables!
    purge_blank_rich_body!
  end

  def purge_blank_rich_body!
    return unless @bullet.rich_body.blank?

    ActionText::RichText.find_by(record: @bullet, name: 'rich_body')&.destroy
  end
end
