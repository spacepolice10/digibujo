# frozen_string_literal: true

class HooksController < ApplicationController
  def index
    @hooks = Current.user.hooks.order(created_at: :desc)
    @created_hook_code = flash[:hook_code]

    respond_to do |format|
      format.html
      format.json
    end
  end

  def new
    @hook = Current.user.hooks.new
  end

  def create
    @hook = Current.user.hooks.new(hook_params)

    if @hook.save
      respond_to do |format|
        format.html do
          flash[:hook_code] = @hook.code
          redirect_to hooks_path
        end
        format.json { render :create, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @hook.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @hook = Current.user.hooks.find(params[:id])
    @hook.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to hooks_path, status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def hook_params
    params.require(:hook).permit(:name)
  end
end
