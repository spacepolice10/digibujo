# frozen_string_literal: true

class PinnedController < ApplicationController
  before_action :ensure_turbo_frame_request, only: :index, if: :turbo_frame_request?

  def index
    pinned = Current.user.pinned_entities.includes(:pinnable).order(created_at: :desc)
    @items = pinned.where.not(pinnable_type: "Bucket")
    @buckets = pinned.where(pinnable_type: "Bucket")
  end

  private

  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end

  def ensure_turbo_frame_request
    head :not_found unless request.headers['Turbo-Frame'] == 'pinned_bullets'
  end
end
