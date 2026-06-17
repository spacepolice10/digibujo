# frozen_string_literal: true

class TightenBucketHierarchy < ActiveRecord::Migration[8.1]
  def up
    User.find_each do |user|
      future_bucket = FutureBucket.find_or_create_by!(user_id: user.id)
      ensure_future_bucket_row!(user, future_bucket)

      MonthlyBucket.where(user_id: user.id, future_bucket_id: nil).update_all(future_bucket_id: future_bucket.id)
    end

    User.find_each do |user|
      orphan_bundles = Bundle.where(user_id: user.id, collection_id: nil)
      next if orphan_bundles.empty?

      loose_notes = user.buckets.find_by(bucketable_type: 'Collection', name: 'loose notes')
      collection = loose_notes&.bucketable || create_loose_notes_collection!(user)

      orphan_bundles.update_all(collection_id: collection.id)
    end

    change_column_null :bundles, :collection_id, false
    change_column_null :monthly_buckets, :future_bucket_id, false
  end

  def down
    change_column_null :bundles, :collection_id, true
    change_column_null :monthly_buckets, :future_bucket_id, true
  end

  private

  def ensure_future_bucket_row!(user, future_bucket)
    return if Bucket.exists?(user_id: user.id, bucketable: future_bucket)

    Bucket.create!(user_id: user.id, bucketable: future_bucket, name: 'Future Log')
  end

  def create_loose_notes_collection!(user)
    collection = Collection.create!
    Bucket.create!(user_id: user.id, bucketable: collection, name: 'Loose Notes')
    collection
  end
end
