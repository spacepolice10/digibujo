# frozen_string_literal: true

# Unauthenticated intake: external apps POST JSON to create a Pending bullet.
class HookIntakesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  rate_limit to: 60, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  def create
    hook = Hook.authenticate(params[:code])
    return head :not_found unless hook

    @bullet = hook.create_pending_bullet!(
      author_name: intake_params[:author_name],
      bulletable_type: intake_params[:bulletable_type],
      body: intake_params[:body]
    )

    response.set_header('Location', bullet_url(@bullet))
    render template: 'bullets/create', status: :created
  rescue ArgumentError
    render json: { bulletable_type: ['is invalid'] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: e.record.errors, status: :unprocessable_entity
  end

  private

  def intake_params
    params.permit(:author_name, :bulletable_type, :body)
  end
end
