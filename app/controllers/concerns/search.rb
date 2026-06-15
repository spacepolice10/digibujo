# frozen_string_literal: true

module Search
  extend ActiveSupport::Concern

  private

  def q
    params[:q].to_s.strip
  end

  def sanitized_q
    @sanitized_q ||= ActiveRecord::Base.sanitize_sql_like(q.downcase)
  end

  def search_projects
    projects = Current.user.projects
    return projects.order(:name) if q.blank?

    projects.where('name LIKE ?', "%#{sanitized_q}%").order(:name)
  end

  def search_buckets
    buckets = Current.user.buckets.includes(:bucketable, :bullets)
    return buckets.order(:name) if q.blank?

    buckets.where('name LIKE ?', "%#{sanitized_q}%").order(:name)
  end

  def search_bullets
    bullets = Current.user.bullets.includes(:projects, bucket: :bucketable)
    return bullets if q.blank?

    matching_bullets = bullets.select { |bullet| searchable_text(bullet).include?(q.downcase) }
    bullets.where(id: matching_bullets.map(&:id))
  end

  def searchable_text(bullet)
    bucket_names = [bullet.bucket&.name].compact
    project_names = bullet.projects.map(&:name)
    [bullet.body.to_plain_text, bullet.rich_body&.to_plain_text.to_s, *bucket_names, *project_names].join(' ').downcase
  end
end
