# frozen_string_literal: true

class PinnedController < ApplicationController
  include PreparePinned

  before_action :ensure_turbo_frame_request, only: :index, if: :turbo_frame_request?

  def index
    @bullets = pinned_bullets
    @buckets = pinned_buckets
  end

  private

  def turbo_frame_request?
    request.headers["Turbo-Frame"].present?
  end

  def ensure_turbo_frame_request
    head :not_found unless request.headers["Turbo-Frame"] == "pinned_bullets"
  end
end
