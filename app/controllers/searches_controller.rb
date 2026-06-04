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

  def scoped_bullets
    Current.user.bullets.includes(bucket: :bucketable)
    return scoped_bullets if @q.blank?

    matching_bullets = scoped_bullets.select { |bullet| searchable_text(bullet).include?(@q.downcase) }
    scoped_bullets.where(id: matching_bullets.map(&:id))
  end

  def searchable_text(bullet)
    bucket_names = [bullet.bucket&.name].compact
    [bullet.content.to_plain_text, *bucket_names].join(' ').downcase
  end
end
