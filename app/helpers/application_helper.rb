# frozen_string_literal: true

module ApplicationHelper
  def bucket_palette_path(bucket)
    bucketable = bucket.bucketable
    case bucketable
    when Project then project_path(bucketable)
    when Collection then collection_path(bucketable)
    when Monthlylog then monthlylog_path(bucketable)
    else raise ArgumentError, "Unknown bucketable type: #{bucketable.class}"
    end
  end

  def render_bullet_compact(bullet)
    render "bullets/compact", bullet: bullet
  end
end
