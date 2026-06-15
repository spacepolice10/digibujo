# frozen_string_literal: true

class AddParentToBuckets < ActiveRecord::Migration[8.1]
  def change
    add_reference :buckets, :parent, foreign_key: { to_table: :buckets }
  end
end
