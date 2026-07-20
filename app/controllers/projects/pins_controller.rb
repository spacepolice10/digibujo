# frozen_string_literal: true

module Projects
  class PinsController < ApplicationController
    before_action :set_project

    def create
      @project.pin!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: projects_path }
      end
    end

    def destroy
      @project.unpin!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: projects_path }
      end
    end

    private

    def set_project
      @project = Current.user.projects.find(params.require(:project_id))
    end
  end
end
