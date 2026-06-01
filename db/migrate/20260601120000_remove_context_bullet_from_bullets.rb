# frozen_string_literal: true

class RemoveContextBulletFromBullets < ActiveRecord::Migration[8.1]
  def change
    remove_reference :bullets, :context_bullet, foreign_key: { to_table: :bullets, on_delete: :nullify }, index: true
  end
end
