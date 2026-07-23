# frozen_string_literal: true

module Home
  class ActivitiesController < ApplicationController
    def index
      @activities = Current.user.activities
                           .includes(:subject)
                           .order(created_at: :desc)
                           .limit(6)
    end
  end
end
