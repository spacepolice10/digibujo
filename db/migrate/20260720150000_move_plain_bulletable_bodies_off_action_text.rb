# frozen_string_literal: true

# Task/Event/Voice keep a plain text body column. Note alone retains
# ActionText (Lexxy). Copy existing rich-text plain text into the new columns
# and drop those ActionText rows.
class MovePlainBulletableBodiesOffActionText < ActiveRecord::Migration[8.1]
  PLAIN_TYPES = %w[Task Event Voice].freeze

  def up
    add_column :tasks, :body, :text, null: false, default: ''
    add_column :events, :body, :text, null: false, default: ''
    add_column :voices, :body, :text, null: false, default: ''

    say_with_time 'copy Task/Event/Voice ActionText bodies to plain columns' do
      ActionText::RichText.where(name: 'body', record_type: PLAIN_TYPES).find_each do |rich_text|
        plain = rich_text.body.to_plain_text.to_s
        table = rich_text.record_type.tableize
        execute <<~SQL.squish
          UPDATE #{table}
             SET body = #{connection.quote(plain)}
           WHERE id = #{rich_text.record_id.to_i}
        SQL
        rich_text.destroy!
      end
    end
  end

  def down
    say_with_time 'restore Task/Event/Voice ActionText bodies from plain columns' do
      PLAIN_TYPES.each do |type|
        table = type.tableize
        select_all("SELECT id, body FROM #{table}").each do |row|
          body = row['body'].to_s
          next if body.blank?

          ActionText::RichText.create!(
            record_type: type,
            record_id: row['id'],
            name: 'body',
            body: "<div>#{ERB::Util.html_escape(body)}</div>"
          )
        end
      end
    end

    remove_column :tasks, :body
    remove_column :events, :body
    remove_column :voices, :body
  end
end
