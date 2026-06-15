# frozen_string_literal: true

module PrepareBullets
  extend ActiveSupport::Concern

  MAX_BULK_BULLET_IDS = 200

  private

  def prepare_bullets
    ids = params.fetch(:bullet_ids, '').split(',').map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
    raise ActiveRecord::RecordNotFound if ids.empty? || ids.size > MAX_BULK_BULLET_IDS

    @bullets = Current.user.bullets.where(id: ids).order(:id)
    raise ActiveRecord::RecordNotFound if @bullets.count != ids.size
  end
end
