# frozen_string_literal: true

class RenameBucketColoursToNames < ActiveRecord::Migration[8.1]
  NUMERIC_TO_NAME = {
    "1" => "violet",
    "2" => "cobalt",
    "3" => "teal",
    "4" => "emerald",
    "5" => "gold",
    "6" => "vermillion",
    "7" => "magenta",
    "8" => "inks",
  }.freeze

  NAME_TO_NUMERIC = NUMERIC_TO_NAME.invert.freeze

  def up
    rename_colours(NUMERIC_TO_NAME)
  end

  def down
    rename_colours(NAME_TO_NUMERIC)
  end

  private

  def rename_colours(mapping)
    whens = mapping.map { |from, to| "WHEN '#{from}' THEN '#{to}'" }.join(" ")
    keys = mapping.keys.map { |key| "'#{key}'" }.join(", ")

    execute <<~SQL.squish
      UPDATE buckets
      SET colour = CASE colour #{whens} ELSE colour END
      WHERE colour IN (#{keys})
    SQL
  end
end
