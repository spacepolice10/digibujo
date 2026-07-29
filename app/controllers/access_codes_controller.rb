# frozen_string_literal: true

class AccessCodesController < ApplicationController
  def index
    @access_codes = Current.user.access_codes.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json
    end
  end

  def create
    @access_code = Current.user.access_codes.new(access_code_params)

    if @access_code.save
      render :create, status: :created
    else
      render json: @access_code.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @access_code = Current.user.access_codes.find(params[:id])
    @access_code.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to access_codes_path, status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def access_code_params
    params.require(:access_code).permit(:description)
  end
end
