# frozen_string_literal: true

class AddOnboardedToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :onboarded, :boolean, default: false, null: false

    execute <<~SQL.squish
      UPDATE users
      SET onboarded = TRUE
      WHERE EXISTS (
        SELECT 1 FROM buckets
        WHERE buckets.user_id = users.id
          AND buckets.bucketable_type = 'Collection'
          AND buckets.name = 'loose notes'
      )
    SQL
  end

  def down
    remove_column :users, :onboarded
  end
end
