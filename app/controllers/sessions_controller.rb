class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    user = User.find_or_create_by(email_address: params[:email_address])

    if user.persisted?
      _record, code = LoginCode.create_for(user)
      SessionMailer.login_code(user, code).deliver_later
    end

    session[:login_email] = params[:email_address]
    redirect_to new_session_code_path
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
