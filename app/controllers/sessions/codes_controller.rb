# frozen_string_literal: true

module Sessions
  class CodesController < ApplicationController
    layout 'session'

    allow_unauthenticated_access
    rate_limit to: 5, within: 3.minutes, only: :create, with: lambda {
      redirect_to new_session_code_path, alert: 'Try again later.'
    }

    def new
      @email = session[:login_email]
      redirect_to new_session_path unless @email
    end

    def create
      LoginCode.sweep

      user = User.find_by(email_address: session[:login_email])

      if user && (login_code = user.login_codes.find { |lc| !lc.expired? && lc.code_matches?(params[:code]) })
        login_code.destroy
        user.login_codes.delete_all
        session.delete(:login_email)

        if session.delete(:auth_flow) == 'signup'
          session[:signup_user_id] = user.id
          redirect_to new_signup_completion_path
        else
          start_new_session_for(user)
          redirect_to after_authentication_url
        end
      else
        redirect_to new_session_code_path, alert: 'Invalid or expired code.'
      end
    end
  end
end
