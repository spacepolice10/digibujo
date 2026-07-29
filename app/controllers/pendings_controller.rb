# frozen_string_literal: true

class PendingsController < ApplicationController
  before_action :ensure_turbo_frame_request, only: :show, if: :turbo_frame_request?

  def show
    @pending = Pending.provision!(Current.user)
    inbox = Pending.inbox_for(Current.user)

    if pending_list_frame?
      @bullets = inbox.limit(50).to_a
      @pending_count = @bullets.size
    else
      @bullets = set_page_and_extract_portion_from(
        inbox,
        per_page: [15, 30, 50, 100]
      )
    end
  end

  private

  def turbo_frame_request?
    request.headers['Turbo-Frame'].present?
  end

  def pending_list_frame?
    request.headers['Turbo-Frame'] == 'pending_list'
  end

  def ensure_turbo_frame_request
    head :not_found unless pending_list_frame?
  end
end
