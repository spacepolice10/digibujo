class Bullets::CompletesController < ApplicationController
  before_action :set_task_and_bullet

  def create
    @task.complete!
    respond_to do |format|
      format.turbo_stream { render 'bullets/completes/create' }
      format.html { redirect_to bullets_path }
    end
  end

  def destroy
    @task.uncomplete!
    respond_to do |format|
      format.turbo_stream { render 'bullets/completes/destroy' }
      format.html { redirect_to bullets_path }
    end
  end

  private

  def set_task_and_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
    @task = @bullet.bulletable
  end
end
