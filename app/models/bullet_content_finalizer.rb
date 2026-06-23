# frozen_string_literal: true

class BulletContentFinalizer
  NOTE_ATTRIBUTES = %i[mood].freeze

  def self.call(bullet, bulletable_attributes: nil)
    new(bullet, bulletable_attributes:).call
  end

  def initialize(bullet, bulletable_attributes: nil)
    @bullet = bullet
    @bulletable_attributes = bulletable_attributes
  end

  def call
    update_bulletable!
    @bullet.reload
  end

  private

  def update_bulletable!
    attrs = @bulletable_attributes
    return unless attrs.present? && @bullet.bulletable.is_a?(Note)

    permitted = attrs.respond_to?(:permit) ? attrs.permit(*NOTE_ATTRIBUTES) : attrs.slice(*NOTE_ATTRIBUTES)
    @bullet.bulletable.update!(permitted)
  end
end
