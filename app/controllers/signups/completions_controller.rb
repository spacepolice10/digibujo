# frozen_string_literal: true

module Signups
  class CompletionsController < ApplicationController
    layout 'session'

    allow_unauthenticated_access
    before_action :set_user

    def new
      @signup = Signup.new(user: @user)
    end

    def create
      @signup = Signup.new(user: @user)

      if @signup.complete
        session.delete(:auth_flow)
        session.delete(:signup_user_id)
        session.delete(:login_email)
        start_new_session_for(@signup.user)
        redirect_to after_authentication_url
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find_by(id: session[:signup_user_id])
      return if @user.present?

      redirect_to new_signup_path, alert: 'Please sign up first.'
    end
  end
end
