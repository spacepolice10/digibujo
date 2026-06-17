class AddPeopleExpandedToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :people_expanded, :boolean, default: true, null: false
  end
end
