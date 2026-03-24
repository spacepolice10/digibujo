class TasksController < ApplicationController
  layout -> { request.variant.mobile? ? "mobile" : "main-layout" }

  def index
    if params.key?(:sort)
      if params[:sort] == "done_last"
        session[:tasks_sort] = "done_last"
        @done_last = true
      else
        session.delete(:tasks_sort)
        @done_last = false
      end
    else
      @done_last = session[:tasks_sort] == "done_last"
    end

    scope  = Current.user.cards.tasks.includes(:tags)
    scope  = @done_last ? scope.order(done: :asc, created_at: :desc) : scope.timeline_chronological
    @cards = set_page_and_extract_portion_from(scope, per_page: [ 15, 30, 50 ])
    @total = Current.user.cards.tasks.count
    @done  = Current.user.cards.tasks.where(done: true).count
    @pending = @total - @done
  end
end
