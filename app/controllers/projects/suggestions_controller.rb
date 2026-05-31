# frozen_string_literal: true

module Projects
  class SuggestionsController < ApplicationController
    def index
      @frame_id = params[:frame_id].presence || "project_suggestions"
      @projects = Current.user.projects.includes(:bucket)
      @projects = @projects.where("buckets.name LIKE ?", "#{sanitized_query}%") if sanitized_query.present?
      @projects = @projects.limit(10)

      render layout: false
    end

    private

    def sanitized_query
      @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
    end

  end
end
