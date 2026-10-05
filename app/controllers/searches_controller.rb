# frozen_string_literal: true

class SearchesController < ApplicationController
  helper_method :page_results?

  def show
    @q = params[:q].to_s.strip

    if @q.present?
      # The search card shows at most ten rows. The compact menu keeps the global cap.
      limit = request.format.turbo_stream? ? Search::GlobalRequest::LIMIT : 10
      @entries = Search::GlobalRequest.call(user: Current.user, query: @q, limit:)
    else
      @collections = Current.user.collections.active.order(:name)
      @attachments_count = User::Attachments.new(Current.user).attachments.count
      @archived_count = Current.user.bullets.archived.count

      @selections = Search::Selection.in_menu(Current.user) if request.format.html? || turbo_frame_request?
    end
  end

  private

  # Frame results and explicit page updates render full bullet rows.
  # A turbo-stream without view=page stays the compact list.
  def page_results?
    params[:view] == 'page' || turbo_frame_request?
  end
end
