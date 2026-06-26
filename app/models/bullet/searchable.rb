# frozen_string_literal: true

module Bullet::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  def search_name
    body.to_plain_text.truncate(255)
  end

  def search_body
    bucket_names = [bucket&.name].compact
    project_names = projects.map(&:name)
    person_names = people.map(&:name)

    [
      body.to_plain_text,
      *bucket_names,
      *project_names,
      *person_names
    ].compact.join(' ')
  end
end
