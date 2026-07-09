# frozen_string_literal: true

class AuthenticationController < ApplicationController
  layout 'session'

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_authentication_path, alert: 'Try again later.'
  }

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(email_address: authentication_params[:email_address])

    if @signup.create_identity
      session[:login_email] = @signup.user.email_address
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
