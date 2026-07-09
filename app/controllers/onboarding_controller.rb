# frozen_string_literal: true

class OnboardingController < ApplicationController
  layout 'session'

  allow_unauthenticated_access
  before_action :set_user
  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_onboarding_path, alert: 'Try again later.'
  }

  def new
    @signup = Signup.new(user: @user)
  end

  def create
    @signup = Signup.new(user: @user)

    if @signup.complete
      clear_onboarding_access
      start_new_session_for(@signup.user)
      redirect_to after_authentication_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = resume_onboarding_user
    return if @user.present?

    clear_onboarding_access
    redirect_to new_authentication_path, alert: 'Please sign in first.'
  end
end
