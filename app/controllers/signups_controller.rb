# frozen_string_literal: true

class SignupsController < ApplicationController
  layout 'session'

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_signup_path, alert: 'Try again later.'
  }

  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(email_address: signup_params[:email_address])

    if @signup.create_identity
      session[:login_email] = @signup.user.email_address
      session[:auth_flow] = 'signup'
      redirect_to new_session_code_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.permit(:email_address)
  end
end
