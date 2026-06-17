# frozen_string_literal: true

module Home
  # Persists which home page sections are expanded or collapsed per user.
  class SectionsController < ApplicationController
    def expand
      update_column(true)
    end

    def collapse
      update_column(false)
    end

    private

    def update_column(value)
      column = User::Settings::SECTION_COLUMNS[params[:id]]
      return head :unprocessable_entity unless column

      Current.user.settings!.update!(column => value)
      head :ok
    end
  end
end
