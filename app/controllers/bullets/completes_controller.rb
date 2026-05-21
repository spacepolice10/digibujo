class Bullets::CompletesController < ApplicationController
  before_action :set_bullet_and_task

  def create
    return head :unprocessable_entity unless @task

    @task.complete!
    respond_to do |format|
      format.turbo_stream { render "bullets/completes/create" }
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  end

  def destroy
    return head :unprocessable_entity unless @task

    @task.uncomplete!
    respond_to do |format|
      format.turbo_stream { render "bullets/completes/destroy" }
      format.html { redirect_to daylog_path_to(daylog_redirect_date) }
    end
  end

  private

  def set_bullet_and_task
    @bullet = Current.user.bullets.find(params[:bullet_id])
    @task = @bullet.bulletable if @bullet.bulletable.is_a?(Task)
  end
end
