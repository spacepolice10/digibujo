# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show destroy]

  def index
    @projects = Current.user.projects.order(created_at: :desc)
    query = sanitized_query
    @projects = @projects.where("buckets.name LIKE ?", "%#{query}%") if query.present?
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new
    if save_project_with_bucket(@project)
      respond_to do |format|
        format.html { redirect_to project_path(@project) }
        format.json { render json: { project: project_json(@project.reload) }, status: :created }
      end
    else
      @project.name = project_params[:name]
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def show
    scope = Current.user.bullets.where(bucket_id: @project.bucket.id)
      .where(archived: false).distinct
    scope = scope.where(bulletable_type: selected_type) if selected_type.present?
    @bullets = set_page_and_extract_portion_from(scope, per_page: [5, 15, 30, 50])
  end

  def destroy
    dom = helpers.dom_id(@project)
    @project.bucket.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(dom) }
      format.html { redirect_to buckets_path }
    end
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:id])
  end

  def sanitized_query
    @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.downcase)
  end

  def selected_type
    @selected_type ||= params[:type].to_s.classify.presence_in(Bullet.bulletable_types)
  end

  def project_params
    params.require(:project).permit(:name, :colour, :icon)
  end

  def save_project_with_bucket(project)
    ActiveRecord::Base.transaction do
      project.save!
      Current.user.buckets.create!(
        bucketable: project,
        name: project_params[:name],
        colour: project_params[:colour],
        icon: project_params[:icon]
      )
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    project.errors.merge!(e.record.errors) if e.record.is_a?(Bucket)
    false
  end 

  def project_json(project)
    {
      id: project.id,
      bucket_id: project.bucket.id,
      name: project.name,
      colour: project.colour,
      icon: project.icon
    }
  end
end
