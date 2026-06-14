# frozen_string_literal: true

module Publishable
  extend ActiveSupport::Concern

  included do
    has_one :published_entity, as: :publishable, dependent: :destroy
  end

  def publish!
    user.published_entities.create!(publishable: self)
  end

  def unpublish!
    user.published_entities.where(publishable: self).destroy_all
  end

  def published?
    published_entity.present?
  end

  def public_code
    published_entity&.code
  end
end
