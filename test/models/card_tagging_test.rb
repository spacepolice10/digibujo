require "test_helper"

class CardTaggingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # -- Creation --

  test "assigns tags when card is created with tags_string" do
    card = build_card(tags_string: "work, personal")
    card.save!

    assert_equal 2, card.tags.count
    assert_equal %w[work personal], card.tags.map(&:name)
  end

  test "creates missing tags on save" do
    assert_difference "Tag.count", 2 do
      build_card(tags_string: "brand-new, also-new").save!
    end
  end

  test "reuses existing tags instead of duplicating" do
    existing = @user.tags.create!(name: "work")

    assert_no_difference "Tag.count" do
      build_card(tags_string: "work").save!
    end

    assert_equal existing, Card.last.tags.first
  end

  test "assigns tags with colour encoding" do
    card = build_card(tags_string: "urgent:1")
    card.save!

    tag = card.tags.first
    assert_equal "urgent", tag.name
    assert_equal "1", tag.colour
  end

  test "does not overwrite colour of existing tag" do
    existing = @user.tags.create!(name: "work", colour: "2")

    build_card(tags_string: "work:3").save!

    assert_equal "2", existing.reload.colour
  end

  test "no tags assigned when tags_string is blank on creation" do
    card = build_card(tags_string: "")
    card.save!

    assert_empty card.tags
  end

  # -- Editing --

  test "adds new tags when tags_string is updated" do
    card = build_card.tap(&:save!)
    card.update!(tags_string: "work, personal")

    assert_equal %w[work personal], card.tags.reload.map(&:name)
  end

  test "replaces tags on update" do
    card = build_card(tags_string: "old").tap(&:save!)
    card.update!(tags_string: "new")

    assert_equal %w[new], card.tags.reload.map(&:name)
  end

  test "removes all tags when tags_string is cleared" do
    card = build_card(tags_string: "work, personal").tap(&:save!)
    card.update!(tags_string: "")

    assert_empty card.tags.reload
  end

  test "does not touch tags when tags_string is not changed" do
    card = build_card(tags_string: "work").tap(&:save!)

    assert_no_difference "CardTag.count" do
      card.update!(content: "Updated content only")
    end

    assert_equal %w[work], card.tags.reload.map(&:name)
  end

  # -- Getter --

  test "tags_string returns comma-separated tag names" do
    card = build_card(tags_string: "work, personal").tap(&:save!)
    card.reload

    assert_equal "work, personal", card.tags_string
  end

  test "tags_string includes colour for coloured tags" do
    card = build_card(tags_string: "urgent:1").tap(&:save!)
    card.reload

    assert_equal "urgent:1", card.tags_string
  end

  test "tags_string is empty string when card has no tags" do
    card = build_card.tap(&:save!)
    card.reload

    assert_equal "", card.tags_string
  end

  private

  def build_card(tags_string: nil)
    @user.cards.new(content: "Test card", tags_string: tags_string).tap do |card|
      card.cardable = Draft.new
    end
  end
end
