class UnifyDefaultStreams < ActiveRecord::Migration[8.1]
  def up
    add_column :streams, :default, :boolean, default: false, null: false
    add_column :streams, :position, :integer

    # Backfill existing Task/Note streams as defaults, create missing defaults
    User.find_each do |user|
      streams = user.streams.to_a

      Stream::DEFAULTS.each do |attrs|
        existing = streams.find { |s| s.name == attrs[:name] }
        if existing
          existing.update_columns(default: true, position: attrs[:position], fields: existing.fields.merge("icon" => attrs.dig(:fields, "icon"), "colour" => attrs.dig(:fields, "colour")))
        else
          user.streams.create!(
            name: attrs[:name],
            default: true,
            position: attrs[:position],
            fields: attrs[:fields]
          )
        end
      end
    end
  end

  def down
    remove_column :streams, :default
    remove_column :streams, :position
  end
end
