class AddContextCardToCards < ActiveRecord::Migration[8.1]
  def change
    add_reference :cards, :context_card, foreign_key: { to_table: :cards, on_delete: :nullify }, index: true
  end
end
