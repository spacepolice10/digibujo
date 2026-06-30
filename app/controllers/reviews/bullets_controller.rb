# frozen_string_literal: true

module Reviews
  class BulletsController < ApplicationController
    include BulletCreation

    def new
      assign_composer_from_params
      @form_url = review_bullets_path
    end

    def create
      create_bullet
    end

    private

    def redirect_after_create
      redirect_to review_path
    end
  end
end
