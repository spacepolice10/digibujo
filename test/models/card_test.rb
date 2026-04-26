require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "collect marks card triaged and assigns collection" do
    card = @user.cards.create!(cardable: Task.create!, content: "Collect me")
    collection = @user.collections.create!(name: "inbox")

    card.collect!(collection_id: collection.id)

    assert_not_nil card.triaged_at
    assert_equal collection.id, card.collection_id
  end

  test "collect preserves existing triaged_at timestamp" do
    card = @user.cards.create!(cardable: Task.create!, content: "Already triaged")
    first_triage_time = 2.days.ago.change(usec: 0)
    card.update!(triaged_at: first_triage_time)

    card.collect!(collection_name: "Ideas")

    assert_equal first_triage_time, card.reload.triaged_at.change(usec: 0)
  end

  test "schedule marks card triaged and updates date only" do
    card = @user.cards.create!(cardable: Note.create!, content: "Schedule me")
    scheduled_for = 3.days.from_now

    card.schedule!(date: scheduled_for)

    assert_not_nil card.triaged_at
    assert_equal scheduled_for.to_i, card.date.to_i
  end

  test "direct update resolves collection by name" do
    card = @user.cards.create!(cardable: Task.create!, content: "Direct update")

    card.update!(collection_name: "Projects")

    assert_equal "projects", card.reload.collection.name
  end

  test "blank collection_name clears collection" do
    card = @user.cards.create!(cardable: Task.create!, content: "Clear collection")
    card.update!(collection_name: "Inbox")

    card.update!(collection_name: "")

    assert_nil card.reload.collection
  end

  test "auto_archivable excludes pinned cards" do
    due_unpinned = @user.cards.create!(cardable: Task.create!, content: "Due", archives_on: Date.yesterday)
    due_pinned = @user.cards.create!(cardable: Task.create!, content: "Pinned due", archives_on: Date.yesterday, pinned: true)

    ids = Card.auto_archivable.pluck(:id)

    assert_includes ids, due_unpinned.id
    assert_not_includes ids, due_pinned.id
  end

  test "auto_archivable includes stale untriaged cards" do
    stale = @user.cards.create!(cardable: Task.create!, content: "Stale")
    stale.update_columns(created_at: 8.days.ago, updated_at: 8.days.ago)

    fresh = @user.cards.create!(cardable: Task.create!, content: "Fresh")
    fresh.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)

    triaged = @user.cards.create!(cardable: Task.create!, content: "Triaged", triaged_at: Time.current)
    triaged.update_columns(created_at: 10.days.ago, updated_at: 10.days.ago)

    ids = Card.auto_archivable.pluck(:id)

    assert_includes ids, stale.id
    assert_not_includes ids, fresh.id
    assert_not_includes ids, triaged.id
  end

  test "context card must belong to same user" do
    card = @user.cards.create!(cardable: Task.create!, content: "Card")
    outsider = users(:two)
    outsider_context = outsider.cards.create!(cardable: Note.create!, content: "Outside")

    card.context_card = outsider_context

    assert_not card.valid?
    assert_includes card.errors[:context_card], "must belong to the same user"
  end

  test "context card cannot point to itself" do
    card = @user.cards.create!(cardable: Task.create!, content: "Self")

    card.context_card = card

    assert_not card.valid?
    assert_includes card.errors[:context_card], "can't point to itself"
  end
end
