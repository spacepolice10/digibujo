# frozen_string_literal: true

class ProjectsController < ApplicationController
  include BulletListing

  before_action :set_project, only: %i[show destroy]

  def index
    @projects = Current.user.projects.order(created_at: :desc)

    @projects = @projects.where('name LIKE ?', "%#{sanitized_string}%") if sanitized_string.present?
  end

  def new
    @project = Project.new
  end

  def create
    @project = Current.user.projects.build(project_params)
    if @project.save
      redirect_to home_path, notice: 'Project created'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    set_bullet_listing(@project)
  end

  def destroy
    @project.destroy
    redirect_back fallback_location: projects_path, notice: 'Project deleted'
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:id])
  end

  def sanitized_string
    @sanitized_string ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end

  def project_params
    params.require(:project).permit(:name, :colour, :icon)
  end
end
