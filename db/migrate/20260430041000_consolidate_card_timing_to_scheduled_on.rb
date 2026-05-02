class ConsolidateCardTimingToScheduledOn < ActiveRecord::Migration[8.1]
  def up
    add_column :bullets, :scheduled_on, :date

    execute <<~SQL
      UPDATE bullets
      SET scheduled_on = COALESCE(
        pops_on,
        DATE(date)
      )
    SQL

    remove_index :bullets, name: "index_cards_on_user_id_and_pops_on"
    remove_column :bullets, :pops_on, :date
    remove_column :bullets, :date, :datetime

    add_index :bullets, [:user_id, :scheduled_on], name: "index_cards_on_user_id_and_scheduled_on"
  end

  def down
    remove_index :bullets, name: "index_cards_on_user_id_and_scheduled_on"

    add_column :bullets, :date, :datetime
    add_column :bullets, :pops_on, :date

    execute <<~SQL
      UPDATE bullets
      SET date = CASE
        WHEN scheduled_on IS NULL THEN NULL
        ELSE datetime(scheduled_on)
      END,
      pops_on = scheduled_on
    SQL

    remove_column :bullets, :scheduled_on, :date
    add_index :bullets, [:user_id, :pops_on], name: "index_cards_on_user_id_and_pops_on"
  end
end
