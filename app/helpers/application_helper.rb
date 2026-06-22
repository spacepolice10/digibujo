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
end
