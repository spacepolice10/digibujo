module Contextable
  extend ActiveSupport::Concern

  included do
    belongs_to :context_bullet, class_name: 'Bullet', optional: true
    has_many :context_for_bullets,
             class_name: 'Bullet',
             foreign_key: :context_bullet_id,
             dependent: :nullify,
             inverse_of: :context_bullet

    validates :context_bullet_id, numericality: { only_integer: true }, allow_nil: true
    validate :context_bullet_is_not_self
    validate :context_bullet_belongs_to_same_user
  end

  def context_name
    context_bullet&.bulletable&.name.presence || 'Context'
  end

  private

  def context_bullet_is_not_self
    return if context_bullet_id.blank? || id.blank?
    return unless context_bullet_id == id

    errors.add(:context_bullet, "can't point to itself")
  end

  def context_bullet_belongs_to_same_user
    return if context_bullet.blank? || user.blank?
    return if context_bullet.user_id == user_id

    errors.add(:context_bullet, 'must belong to the same user')
  end
end
