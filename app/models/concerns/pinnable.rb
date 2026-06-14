# frozen_string_literal: true

module Pinnable
  extend ActiveSupport::Concern

  included do
    has_one :pinned_entity, as: :pinnable, dependent: :destroy
  end

  def pin!
    user.pinned_entities.find_or_create_by!(pinnable: self)
  end

  def unpin!
    user.pinned_entities.where(pinnable: self).destroy_all
  end

  def pinned?
    pinned_entity.present?
  end
end
