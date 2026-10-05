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
    [body_as_text, filename].compact.join(' ')
  end
end
