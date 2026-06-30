# frozen_string_literal: true

module PrepareBullets
  extend ActiveSupport::Concern

  MAX_BULK_BULLET_IDS = 200

  private

  def prepare_bullet_list_from(bullet_id_parameter)
    bullet_id_parameter.to_s.split(',').map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
  end

  def prepare_bullets_from(bullet_id_parameter)
    bullet_ids = prepare_bullet_list_from(bullet_id_parameter)
    raise ActiveRecord::RecordNotFound if bullet_ids.empty? || bullet_ids.size > MAX_BULK_BULLET_IDS

    bullets = Current.user.bullets.where(id: bullet_ids).order(:id)
    raise ActiveRecord::RecordNotFound if bullets.count != bullet_ids.size

    bullets
  end

  def prepare_bullets
    @bullets = prepare_bullets_from(params[:bullet_ids])
  end

  def bullets_from_param(bullet_id_parameter)
    prepare_bullets_from(bullet_id_parameter)
  end
end
