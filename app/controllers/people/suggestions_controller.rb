# frozen_string_literal: true

module People
  class SuggestionsController < ApplicationController
    def index
      @people = Current.user.mentions.person.order(:name)
      @people = @people.where("name LIKE ?", "%#{sanitized_string}%") if sanitized_string.present?

      render layout: false
    end

    private

    def sanitized_string
      @sanitized_string ||= ActiveRecord::Base.sanitize_sql_like(params[:filter].to_s.strip.downcase)
    end
  end
end
