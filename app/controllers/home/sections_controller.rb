# frozen_string_literal: true

module Home
  # Persists which home page sections are expanded or collapsed per user.
  class SectionsController < ApplicationController
    def update
      unless User::Settings::SECTIONS.include?(params[:id])
        head :unprocessable_entity
        return
      end

      Current.user.settings!.set_section_open(params[:id], params.expect(:open))
      head :ok
    end
  end
end
