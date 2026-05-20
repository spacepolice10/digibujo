class SearchesController < ApplicationController
  def show
    @q = params[:q].to_s.strip
    @bullets = set_page_and_extract_portion_from(search_scope, per_page: [5, 15, 30, 50])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def search_scope
    scope = Current.user.bullets.includes(bucket: :bucketable)
    return scope if @q.blank?

    matching_ids = scope.select { |bullet| searchable_text(bullet).include?(@q.downcase) }.map(&:id)
    scope.where(id: matching_ids)
  end

  def searchable_text(bullet)
    bucket_names = [bullet.bucket&.name].compact
    [bullet.content.to_plain_text, *bucket_names].join(' ').downcase
  end
end
