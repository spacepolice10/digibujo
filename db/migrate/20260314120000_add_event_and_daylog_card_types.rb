class AddEventAndDaylogCardTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
    end

    create_table :daylogs do |t|
    end

    add_column :cards, :ends_date, :date
  end
end
