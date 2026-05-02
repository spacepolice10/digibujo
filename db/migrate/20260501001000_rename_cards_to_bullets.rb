class RenameCardsToBullets < ActiveRecord::Migration[8.1]
  def change
    rename_table :cards, :bullets if table_exists?(:cards)

    rename_column :bullets, :context_card_id, :context_bullet_id if column_exists?(:bullets, :context_card_id)
    rename_index :bullets, "index_cards_on_cardable", "index_bullets_on_cardable" if index_name_exists?(:bullets, "index_cards_on_cardable")
    rename_index :bullets, "index_cards_on_context_card_id", "index_bullets_on_context_bullet_id" if index_name_exists?(:bullets, "index_cards_on_context_card_id")
    rename_index :bullets, "index_cards_on_project_id", "index_bullets_on_project_id" if index_name_exists?(:bullets, "index_cards_on_project_id")
    rename_index :bullets, "index_cards_on_public_code", "index_bullets_on_public_code" if index_name_exists?(:bullets, "index_cards_on_public_code")
    rename_index :bullets, "index_cards_on_user_id", "index_bullets_on_user_id" if index_name_exists?(:bullets, "index_cards_on_user_id")
    rename_index :bullets, "index_cards_on_user_id_and_archived", "index_bullets_on_user_id_and_archived" if index_name_exists?(:bullets, "index_cards_on_user_id_and_archived")
    rename_index :bullets, "index_cards_on_user_id_and_archives_on", "index_bullets_on_user_id_and_archives_on" if index_name_exists?(:bullets, "index_cards_on_user_id_and_archives_on")
    rename_index :bullets, "index_cards_on_user_id_and_done", "index_bullets_on_user_id_and_done" if index_name_exists?(:bullets, "index_cards_on_user_id_and_done")
    rename_index :bullets, "index_cards_on_user_id_and_pinned", "index_bullets_on_user_id_and_pinned" if index_name_exists?(:bullets, "index_cards_on_user_id_and_pinned")
    rename_index :bullets, "index_cards_on_user_id_and_scheduled_on", "index_bullets_on_user_id_and_scheduled_on" if index_name_exists?(:bullets, "index_cards_on_user_id_and_scheduled_on")
    rename_index :bullets, "index_cards_on_user_id_and_triaged_at", "index_bullets_on_user_id_and_triaged_at" if index_name_exists?(:bullets, "index_cards_on_user_id_and_triaged_at")
    rename_index :bullets, "index_cards_on_user_id_and_status", "index_bullets_on_user_id_and_status" if index_name_exists?(:bullets, "index_cards_on_user_id_and_status")

    if foreign_key_exists?(:bullets, column: :context_bullet_id)
      remove_foreign_key :bullets, column: :context_bullet_id
    end
    add_foreign_key :bullets, :bullets, column: :context_bullet_id, on_delete: :nullify unless foreign_key_exists?(:bullets, :bullets, column: :context_bullet_id)

    rename_column :playlist_cards, :card_id, :bullet_id if column_exists?(:playlist_cards, :card_id)
    rename_index :playlist_cards, "index_playlist_cards_on_card_id", "index_playlist_cards_on_bullet_id" if index_name_exists?(:playlist_cards, "index_playlist_cards_on_card_id")
    rename_index :playlist_cards, "index_playlist_cards_on_playlist_id_and_card_id", "index_playlist_cards_on_playlist_id_and_bullet_id" if index_name_exists?(:playlist_cards, "index_playlist_cards_on_playlist_id_and_card_id")

    if foreign_key_exists?(:playlist_cards, :cards)
      remove_foreign_key :playlist_cards, :cards
    end
    if foreign_key_exists?(:playlist_cards, column: :bullet_id) && !foreign_key_exists?(:playlist_cards, :bullets, column: :bullet_id)
      remove_foreign_key :playlist_cards, column: :bullet_id
    end
    add_foreign_key :playlist_cards, :bullets, column: :bullet_id unless foreign_key_exists?(:playlist_cards, :bullets, column: :bullet_id)
  end
end
