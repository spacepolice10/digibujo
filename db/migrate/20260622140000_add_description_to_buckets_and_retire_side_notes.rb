# frozen_string_literal: true

class AddDescriptionToBucketsAndRetireSideNotes < ActiveRecord::Migration[8.1]
  def up
    add_column :buckets, :description, :text

    Bucket.where(bucketable_type: "Collection").find_each do |bucket|
      rich_text = ActionText::RichText.find_by(record_type: "Bucket", record_id: bucket.id, name: "side_note")
      next unless rich_text

      plain_text = rich_text.body.to_plain_text.strip
      bucket.update_column(:description, plain_text) if plain_text.present?
    end

    ActionText::RichText.where(record_type: "Bucket", name: "side_note").delete_all
  end

  def down
    remove_column :buckets, :description
  end
end
