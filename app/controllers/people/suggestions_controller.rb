# frozen_string_literal: true

module People
  class SuggestionsController < ApplicationController
    def index
      @people = Current.user.people.order(:name)
      @people = @people.where('name LIKE ?', "%#{sanitized_query}%") if sanitized_query.present?

      render layout: false
    end

    private

    def sanitized_query
      raw = params[:filter].presence || params[:q].presence || ''
      @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(raw.to_s.strip.downcase)
    end
  end
end
