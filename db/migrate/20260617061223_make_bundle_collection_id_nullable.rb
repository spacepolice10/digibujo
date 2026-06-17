class MakeBundleCollectionIdNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bundles, :collection_id, true
  end
end
