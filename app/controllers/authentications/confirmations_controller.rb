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
      user = AuthCode.consume!(email: session[:login_email], code: params[:code])

      if user
        session.delete(:login_email)
        start_new_session_for(user)
        redirect_to(user.onboarded? ? after_authentication_url : new_onboarding_path)
      else
        redirect_to new_authentication_confirmation_path, alert: 'Invalid or expired code.'
      end
    end
  end
end
