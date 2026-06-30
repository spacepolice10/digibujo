# frozen_string_literal: true

module Sprints
  class BulletsController < ApplicationController
    include BulletCreation

    before_action :set_sprint

    def new
      assign_composer_from_params(bucket_id: @sprint.bucket.id)
      @form_url = sprint_bullets_path(@sprint)
    end

    def create
      create_bullet
    end

    private

    def set_sprint
      @sprint = Current.user.active_sprints.find(params[:sprint_id])
    end

    def redirect
      redirect_to sprint_path(@sprint)
    end
  end
end
