# frozen_string_literal: true

module Bullet::Searchable
  extend ActiveSupport::Concern
  include ::Searchable

  def search_name
    body.to_plain_text.truncate(255)
  end

  def search_body
    bucket_names = [bucket&.name].compact
    mention_names = mentions.map(&:name)

    [
      body.to_plain_text,
      *bucket_names,
      *mention_names
    ].compact.join(' ')
  end
end
