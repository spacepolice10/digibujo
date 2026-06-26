# frozen_string_literal: true

module Projects
  class SuggestionsController < ApplicationController
    def index
      @projects = Current.user.projects.order(:name)
      @projects = @projects.where('name LIKE ?', "%#{sanitized_string}%") if sanitized_string.present?

      render layout: false
    end

    private

    def sanitized_string
      @sanitized_string ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
    end
  end
end
