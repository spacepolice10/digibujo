class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show destroy]

  def index
    @query = params[:q].to_s.strip.downcase
    @projects = if @query.present?
                     Current.user.projects.where("name LIKE ?", "#{@query}%").limit(10)
                   else
                     Current.user.projects
                   end
    @exact_match = @projects.any? { |project| project.name == @query }
    render json: { projects: @projects.map { |project| { id: project.id, name: project.name, colour: project.colour } } }
  end

  def show
    scope = Current.user.bullets.includes(:project).where(project: @project)
    scope = scope.where(bulletable_type: selected_type) if selected_type.present?
    @bullets = set_page_and_extract_portion_from(scope.order(created_at: :desc), per_page: [5, 15, 30, 50])
  end

  def destroy
    @project.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@project) }
      format.html { redirect_to indexing_path }
    end
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:id])
  end

  def selected_type
    @selected_type ||= params[:type].to_s.classify.presence_in(Bullet.bulletable_types)
  end
end
