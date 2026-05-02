class RenameCardableToBulletableOnBullets < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:bullets)

    if column_exists?(:bullets, :cardable_type)
      rename_column :bullets, :cardable_type, :bulletable_type
    end

    if column_exists?(:bullets, :cardable_id)
      rename_column :bullets, :cardable_id, :bulletable_id
    end

    if index_name_exists?(:bullets, "index_bullets_on_cardable")
      rename_index :bullets, "index_bullets_on_cardable", "index_bullets_on_bulletable"
    end
  end
end
