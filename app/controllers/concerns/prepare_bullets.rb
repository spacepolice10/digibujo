# frozen_string_literal: true

module PrepareBullets
  extend ActiveSupport::Concern

  MAX_BULK_BULLET_IDS = 200

  private

  def parse_bullet_ids(raw)
    raw.to_s.split(',').map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
  end

  def bullets_from_param(raw)
    ids = parse_bullet_ids(raw)
    raise ActiveRecord::RecordNotFound if ids.empty? || ids.size > MAX_BULK_BULLET_IDS

    bullets = Current.user.bullets.where(id: ids).order(:id)
    raise ActiveRecord::RecordNotFound if bullets.count != ids.size

    bullets
  end

  def prepare_bullets
    @bullets = bullets_from_param(params.fetch(:bullet_ids, ''))
  end
end
