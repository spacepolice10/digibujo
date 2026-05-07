class StreamsController < ApplicationController
  TASK_DONE_JOIN_SQL = <<~SQL.squish.freeze
    LEFT JOIN tasks ON bullets.bulletable_type = 'Task' AND bullets.bulletable_id = tasks.id
  SQL

  def index
    @streams = Current.user.streams.ordered
    @projects = Current.user.projects
  end

  def show
    @stream    = Current.user.streams.find(params[:id])
    @done_last = params[:sort] == "done_last"
    scope      = if @done_last
      @stream.bullets
        .includes(:project)
        .joins(TASK_DONE_JOIN_SQL)
        .reorder(Arel.sql("COALESCE(tasks.done, 0) ASC"), created_at: :desc)
    else
      @stream.bullets.includes(:project)
    end
    @bullets     = set_page_and_extract_portion_from(scope, per_page: [ 5, 15, 30, 50 ])
  end

  def new
    @stream = Current.user.streams.new
  end

  def create
    @stream = Current.user.streams.new(stream_params)
    if @stream.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to stream_path(@stream) }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @stream = Current.user.streams.find(params[:id])
  end

  def update
    @stream = Current.user.streams.find(params[:id])
    if @stream.update(stream_params)
      redirect_to stream_path(@stream)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    stream = Current.user.streams.find(params[:id])
    stream.destroy
    redirect_to root_path
  end

  private

  def stream_params
    params.require(:stream).permit(:name, :bulletable_type, :sorted_by, :date_from, :date_to, :projects, :icon, :colour)
  end
end
