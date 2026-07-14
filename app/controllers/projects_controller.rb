# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show destroy]

  def index
    @projects = Current.user.mentions.project.order(created_at: :desc)
  end

  def new
    @project = Current.user.mentions.project.build
  end

  def create
    @project = Current.user.mentions.project.build(project_params)
    if @project.save
      redirect_to home_path, notice: "Project created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @bullets = set_page_and_extract_portion_from(
      @project.bullets.order(created_at: :desc),
      per_page: [ 5, 15, 30, 50 ]
    )
  end

  def destroy
    @project.destroy
    redirect_back fallback_location: projects_path, notice: "Project deleted"
  end

  private

  def set_project
    @project = Current.user.mentions.project.find(params[:id])
  end

  def project_params
    params.require(:mention).permit(:name, :colour)
  end
end
