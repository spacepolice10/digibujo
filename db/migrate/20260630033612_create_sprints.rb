class CreateSprints < ActiveRecord::Migration[8.1]
  def change
    create_table :sprints do |t|
      t.date :starts_on
      t.date :ends_on

      t.timestamps
    end
  end
end
