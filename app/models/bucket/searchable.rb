# frozen_string_literal: true

module Bucket::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  def searchable?
    !archived?
  end

  def search_name
    name
  end

  def search_body
    [name, description].compact.join(' ')
  end
end
