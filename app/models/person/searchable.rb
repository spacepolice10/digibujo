# frozen_string_literal: true

module Person::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  def search_name
    name
  end

  def search_body
    handles.map { |handle| [ handle.platform, handle.data ].compact.join(" ") }.join(" ")
  end
end
