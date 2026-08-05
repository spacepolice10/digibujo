# frozen_string_literal: true

class OnboardingController < ApplicationController
  layout 'session'

  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    respond_to do |format|
      format.html { redirect_to new_onboarding_path, alert: 'Try again later.' }
      format.json { head :too_many_requests }
    end
  }

  def new
    @onboarding = Onboarding.new(user: Current.user)
  end

  def create
    @onboarding = Onboarding.new(user: Current.user, data_seed: params[:data_seed])

    if @onboarding.complete
      redirect_to stashed_authentication_path
    else
      render :new, status: :unprocessable_entity
    end
  end
end
