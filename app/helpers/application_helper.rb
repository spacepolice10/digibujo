# frozen_string_literal: true

module ApplicationHelper
  def bucket_palette_path(bucket)
    bucketable = bucket.bucketable
    case bucketable
    when Collection then collection_path(bucketable)
    when FutureBucket then future_path
    when MonthlyBucket then monthly_bucket_path(bucketable)
    else raise ArgumentError, "Unknown bucketable type: #{bucketable.class}"
    end
  end

  def render_bullet(bullet, draggable: false, monthly_bucket: false)
    render 'bullets/bullet', bullet: bullet, draggable: draggable, monthly_bucket: monthly_bucket
  end

  def render_monthly_bucket_bullet(bullet)
    render_bullet(bullet, draggable: true, monthly_bucket: true)
  end

  def monthly_bucket_composer_frame_id(pops_on)
    pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned"
  end

  def monthly_bucket_composer_frame_class(pops_on)
    "bullet_pops_on_#{pops_on}"
  end

  def render_bullet_compact(bullet)
    render 'bullets/compact', bullet: bullet
  end
end
