# frozen_string_literal: true

module Bullet::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  def searchable?
    !archived?
  end

  def search_name
    name.to_s.truncate(255)
  end

  def search_body
    [
      searchable_body,
      filename,
      *collections.map(&:name)
    ].compact.join(' ')
  end

  private

  def searchable_body
    value = body
    value.respond_to?(:to_plain_text) ? value.to_plain_text.to_s : value.to_s
  end
end
