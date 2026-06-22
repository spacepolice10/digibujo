# frozen_string_literal: true

module ApplicationHelper
  def bucket_palette_path(bucket)
    bucketable = bucket.bucketable
    case bucketable
    when Collection then collection_path(bucketable)
    when FutureBucket then future_path
    when MonthlyBucket then future_monthly_bucket_path(bucketable)
    else raise ArgumentError, "Unknown bucketable type: #{bucketable.class}"
    end
  end

  def monthly_bucket_composer_frame_id(pops_on)
    pops_on.present? ? "composer_#{pops_on.to_date.iso8601}" : "composer_unplanned"
  end

  def monthly_bucket_composer_frame_class(pops_on)
    "bullet_pops_on_#{pops_on}"
  end
end
