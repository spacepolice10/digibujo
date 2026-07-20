# frozen_string_literal: true

class SearchReindexJob < ApplicationJob
  SEARCHABLE_MODELS = [ Project, Bucket, Bullet ].freeze

  def perform
    SEARCHABLE_MODELS.each do |model|
      model.find_each do |record|
        record.reindex
      end
    end
  end
end
