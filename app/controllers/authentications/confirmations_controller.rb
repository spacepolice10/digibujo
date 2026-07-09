# frozen_string_literal: true

module Authentications
  class ConfirmationsController < ApplicationController
    layout 'session'

    allow_unauthenticated_access
    rate_limit to: 5, within: 3.minutes, only: :create, with: lambda {
      redirect_to new_authentication_confirmation_path, alert: 'Try again later.'
    }

    def new
      @email = session[:login_email]
      redirect_to new_authentication_path unless @email
    end

    def create
      LoginCode.sweep

      user = User.find_by(email_address: session[:login_email])

      if user && (login_code = user.login_codes.find { |lc| !lc.expired? && lc.code_matches?(params[:code]) })
        login_code.destroy
        user.login_codes.delete_all
        session.delete(:login_email)

        if user.needs_onboarding?
          grant_onboarding_access(user)
          redirect_to new_onboarding_path
        else
          start_new_session_for(user)
          redirect_to after_authentication_url
        end
      else
        redirect_to new_authentication_confirmation_path, alert: 'Invalid or expired code.'
      end
    end
  end
end
