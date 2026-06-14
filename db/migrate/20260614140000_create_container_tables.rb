class CreateContainerTables < ActiveRecord::Migration[8.1]
  def change
    create_table :bundles do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :future_buckets do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :monthly_buckets do |t|
      t.references :future_bucket, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :period_from
      t.date :period_to
      t.timestamps
    end
  end
end
