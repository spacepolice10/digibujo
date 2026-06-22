# frozen_string_literal: true

class AllowMultipleFutureBucketsPerUser < ActiveRecord::Migration[8.1]
  def change
    remove_index :future_buckets, :user_id
    add_index :future_buckets, :user_id
  end
end
