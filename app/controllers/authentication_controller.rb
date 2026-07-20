# frozen_string_literal: true

class AuthenticationController < ApplicationController
  layout 'session'

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 2.minutes, only: :create, with: lambda {
    redirect_to new_authentication_path, alert: 'Try again in a few minutes.'
  }

  def new
    @user = User.new
  end

  def create
    email = User.normalize_value_for(:email_address, authentication_params[:email_address])
    @user = User.find_or_initialize_by(email_address: email)
    if @user.save
      _record, code = AuthCode.create_for(@user)
      SessionMailer.login_code(@user, code).deliver_later
      session[:login_email] = @user.email_address
      redirect_to new_authentication_confirmation_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to new_authentication_path, status: :see_other
  end

  private

  def authentication_params
    params.permit(:email_address)
  end
end
