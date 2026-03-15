module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :card_tags, dependent: :destroy
    has_many :tags, through: :card_tags

    attribute :tags_string, :string

    after_initialize do
      unless tags_string_changed?
        self.tags_string = build_tags_string
        clear_attribute_changes([ :tags_string ])
      end
    end

    before_save :assign_tags, if: -> { tags_string_changed? }
  end

  private

  def build_tags_string
    tags.map { |t| t.colour.present? ? "#{t.name}:#{t.colour}" : t.name }.join(", ")
  end

  def assign_tags
    self.tags = tags_string.to_s.split(",").map(&:strip).reject(&:blank?).map do |entry|
      name, colour = entry.split(":", 2)
      tag = user.tags.find_or_initialize_by(name: name.downcase)
      tag.colour = colour if colour.present? && tag.new_record?
      tag.save!
      tag
    end
  end
end
