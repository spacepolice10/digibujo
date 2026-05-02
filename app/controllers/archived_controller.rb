class ArchivedController < ApplicationController
  def index
    @bullets = set_page_and_extract_portion_from(
      Current.user.bullets.includes(:project).archived.order(updated_at: :desc),
      per_page: [ 15, 30, 50 ]
    )
    @total = Current.user.bullets.archived.count
  end
end
