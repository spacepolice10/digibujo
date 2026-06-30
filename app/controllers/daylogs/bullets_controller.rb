# frozen_string_literal: true

module Daylogs
  class BulletsController < ApplicationController
    include BulletCreation

    def new
      prepare_bullet
    end

    def create
      create_bullet
    end

    private

    def redirect
      redirect_to daylog_path(date: @selected_date.iso8601)
    end
  end
end
