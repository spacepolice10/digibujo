# frozen_string_literal: true

class CompletedController < ApplicationController
  def index
    @bullets = set_page_and_extract_portion_from(
      Current.user.bullets.includes(:collections).done.order(done_at: :desc),
      per_page: [15, 30, 50]
    )
    @amount_of_completed = Current.user.bullets.done.count
  end
end
