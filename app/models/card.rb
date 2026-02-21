class Card < ApplicationRecord
  belongs_to :user
  delegated_type :cardable, types: %w[Task Note], dependent: :destroy

  has_rich_text :content
  has_many :card_tags, dependent: :destroy
  has_many :tags, through: :card_tags

  before_save :assign_tags, if: -> { @tag_names_input }

  def title
    content.to_plain_text.lines.first&.strip.presence || "Untitled"
  end

  def tag_names
    tags.pluck(:name).join(", ")
  end

  def tag_names=(names)
    @tag_names_input = names
  end

  private

  def assign_tags
    self.tags = @tag_names_input.split(",").map(&:strip).reject(&:blank?).map do |name|
      user.tags.find_or_create_by!(name: name.downcase)
    end
    @tag_names_input = nil
  end
end
