# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show destroy]

  def index
    @projects = Current.user.projects.order(created_at: :desc)

    @projects = @projects.where("name LIKE ?", "%#{sanitized_string}%") if sanitized_string.present?
  end

  def new
    @project = Project.new
  end

  def create
    @project = Current.user.projects.build(project_params)
    if @project.save
      redirect_back fallback_location: projects_path, notice: "Project created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    scoped_bullets = Current.user.bullets.joins(:projects)
      .where(projects: { id: @project.id })
      .where(archived: false)
      .distinct
    scoped_bullets = scoped_bullets.where(bulletable_type: selected_type) if selected_type.present?
    @bullets = set_page_and_extract_portion_from(scoped_bullets, per_page: [5, 15, 30, 50])
  end

  def destroy
    @project.destroy
    redirect_back fallback_location: projects_path, notice: "Project deleted"
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:id])
  end

  def sanitized_string
    @sanitized_string ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end

  def selected_type
    @selected_type ||= params[:type].to_s.classify.presence_in(Bullet.bulletable_types)
  end

  def project_params
    params.require(:project).permit(:name, :colour, :icon)
  end
end
