module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :card_tags, dependent: :destroy
    has_many :tags, through: :card_tags

    before_save :assign_tags, if: -> { @tag_names_input.present? }
  end

  def tag_names
    tags.map { |t| t.colour.present? ? "#{t.name}:#{t.colour}" : t.name }.join(", ")
  end

  def tag_names=(names)
    @tag_names_input = Array(names).join(", ")
  end

  private

  def assign_tags
    self.tags = @tag_names_input.split(",").map(&:strip).reject(&:blank?).map do |entry|
      name, colour = entry.split(":", 2)
      tag = user.tags.find_or_initialize_by(name: name.downcase)
      tag.colour = colour if colour.present? && tag.new_record?
      tag.save!
      tag
    end
    @tag_names_input = nil
  end
end
