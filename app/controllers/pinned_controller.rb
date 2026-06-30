# frozen_string_literal: true

class PinnedController < ApplicationController
  before_action :ensure_turbo_frame_request, only: :index, if: :turbo_frame_request?

  def index
    @pinned_entities = Current.user.pinned_entities
                              .includes(pinnable: { bucket: :bucketable })
                              .order(created_at: :desc)
  end

  private

  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end

  def ensure_turbo_frame_request
    head :not_found unless request.headers['Turbo-Frame'] == 'pinned_list'
  end
end
