class SearchesController < ApplicationController
  def show
    @q = params[:q].to_s.strip
    @bullets = set_page_and_extract_portion_from(scoped_bullets, per_page: [5, 15, 30, 50])
    @buckets = scoped_buckets

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def scoped_bullets
    scoped_bullets = Current.user.bullets.includes(bucket: :bucketable)
    return scoped_bullets if @q.blank?

    matching_bullets = scoped_bullets.select { |bullet| searchable_text(bullet).include?(@q.downcase) }
    scoped_bullets.where(id: matching_bullets.map(&:id))
  end

  def scoped_buckets
    buckets = Current.user.buckets.includes(:bucketable, :bullets)
    return buckets.order(:name) if @q.blank?

    buckets.where("name LIKE ?", "%#{sanitized_query}%").order(:name)
  end

  def sanitized_query
    @sanitized_query ||= ActiveRecord::Base.sanitize_sql_like(@q.downcase)
  end

  def searchable_text(bullet)
    bucket_names = [bullet.bucket&.name].compact
    [bullet.content.to_plain_text, *bucket_names].join(" ").downcase
  end
end
