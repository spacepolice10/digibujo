class UpdateBucketableTypeForTimespread < ActiveRecord::Migration[8.1]
  def up
    Bucket.where(bucketable_type: "Monthlylog").update_all(bucketable_type: "TimeSpread")
  end

  def down
    Bucket.where(bucketable_type: "TimeSpread").update_all(bucketable_type: "Monthlylog")
  end
end
