# frozen_string_literal: true

module Searches
  class SelectionsController < ApplicationController
    def create
      searchable_type = params.require(:searchable_type)
      searchable_id = params.require(:searchable_id)

      searchable = find_searchable!(searchable_type, searchable_id)

      Search::Selection.record!(
        user: Current.user,
        searchable_type: searchable_type,
        searchable_id: searchable.id,
        query: params[:query]
      )

      head :no_content
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def find_searchable!(type, id)
      case type
      when 'Mention' then Current.user.mentions.find(id)
      when 'Bucket' then Current.user.buckets.find(id)
      when 'Bullet' then Current.user.bullets.find(id)
      else
        raise ActiveRecord::RecordNotFound
      end
    end
  end
end
