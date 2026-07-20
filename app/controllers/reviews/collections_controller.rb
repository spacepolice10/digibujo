# frozen_string_literal: true

module Reviews
  class CollectionsController < ApplicationController
    def index
      @review_to = params[:to].present? ? params[:to].to_date : Date.current
      @review_from = params[:from].present? ? params[:from].to_date : @review_to - 6.days

      @collections_q = params[:q].to_s.strip.presence
      collections = Current.user.collections
                         .merge(Bucket.active.matching_name(params[:q]))
                         .order('buckets.name')
      page = GearedPagination::Recordset.new(collections, per_page: [8, 16, 24])
                                        .page(params[:collections_page])
      @collections = page.records
      @collections_page = page

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end
  end
end
