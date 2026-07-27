# frozen_string_literal: true

# Every bulletable now stores its body as Action Text (Lexxy), so the chat
# composer can use a single editor for all types. Copy the plain text columns
# of Task/Event/Voice into rich text records and drop the columns.
class MoveBulletableBodiesToActionText < ActiveRecord::Migration[8.1]
  PLAIN_TYPES = %w[Task Event Voice].freeze

  def up
    say_with_time 'copy Task/Event/Voice plain bodies into ActionText' do
      PLAIN_TYPES.each { |type| copy_plain_bodies(type) }
    end

    PLAIN_TYPES.each { |type| remove_column type.tableize.to_sym, :body }
  end

  def down
    PLAIN_TYPES.each do |type|
      add_column type.tableize.to_sym, :body, :text, null: false, default: ''
    end

    say_with_time 'restore Task/Event/Voice plain bodies from ActionText' do
      restore_plain_bodies
    end
  end

  private

  def copy_plain_bodies(type)
    select_all("SELECT id, body FROM #{type.tableize}").each do |row|
      next if row['body'].to_s.strip.blank?
      next if rich_text_for(type, row['id'])

      ActionText::RichText.create!(
        record_type: type, record_id: row['id'],
        name: 'body', body: paragraphs_for(row['body'])
      )
    end
  end

  def restore_plain_bodies
    ActionText::RichText.where(name: 'body', record_type: PLAIN_TYPES).find_each do |rich_text|
      table = rich_text.record_type.tableize
      plain = connection.quote(rich_text.body.to_plain_text.to_s)
      execute("UPDATE #{table} SET body = #{plain} WHERE id = #{rich_text.record_id.to_i}")
      rich_text.destroy!
    end
  end

  def rich_text_for(type, record_id)
    ActionText::RichText.find_by(name: 'body', record_type: type, record_id: record_id)
  end

  def paragraphs_for(text)
    text.to_s.strip.split("\n").map do |line|
      line.strip.empty? ? '<p><br></p>' : "<p>#{ERB::Util.html_escape(line)}</p>"
    end.join
  end
end
