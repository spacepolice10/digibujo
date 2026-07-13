# frozen_string_literal: true

class OnboardingController < ApplicationController
  layout 'session'

  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_onboarding_path, alert: 'Try again later.'
  }

  def new
    @onboarding = Onboarding.new(user: Current.user)
  end

  def create
    @onboarding = Onboarding.new(user: Current.user)

    if @onboarding.complete
      redirect_to after_authentication_url
    else
      render :new, status: :unprocessable_entity
    end
  end
end
