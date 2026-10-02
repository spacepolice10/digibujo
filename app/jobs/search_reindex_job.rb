# frozen_string_literal: true

class SearchReindexJob < ApplicationJob
  SEARCHABLE_MODELS = [Collection, Bullet].freeze

  def perform
    SEARCHABLE_MODELS.each do |model|
      model.find_each(&:reindex)
    end
  end
end
