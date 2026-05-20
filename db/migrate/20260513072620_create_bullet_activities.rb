class CreateBulletActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :bullet_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :bullet_id, null: false
      t.string :action, null: false

      t.timestamps
    end

    add_index :bullet_activities, [ :user_id, :created_at ]
    add_index :bullet_activities, [ :bullet_id, :created_at ]
  end
end
