# frozen_string_literal: true

module Projects
  class SuggestionsController < ApplicationController
    def index
      @projects = Current.user.projects.order(:name)
      @projects = @projects.where("name LIKE ?", "%#{sanitized_query}%") if sanitized_query.present?

      render layout: false
    end

    private

    def sanitized_query
      raw = params[:filter].presence || params[:q].presence || ""
      @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(raw.to_s.strip.downcase)
    end
  end
end
