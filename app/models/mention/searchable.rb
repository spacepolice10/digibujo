# frozen_string_literal: true

module Mention::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  def search_name
    name
  end

  def search_body
    name
  end
end
