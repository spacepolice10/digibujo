require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "collect marks card triaged and assigns project" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Collect me")
    project = @user.projects.create!(name: "inbox")

    card.collect!(project_id: project.id)

    assert_not_nil card.triaged_at
    assert_equal project.id, card.project_id
  end

  test "collect preserves existing triaged_at timestamp" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Already triaged")
    first_triage_time = 2.days.ago.change(usec: 0)
    card.update!(triaged_at: first_triage_time)

    card.collect!(project_name: "Ideas")

    assert_equal first_triage_time, card.reload.triaged_at.change(usec: 0)
  end

  test "schedule marks card triaged and updates scheduled_on only" do
    card = @user.bullets.create!(bulletable: Note.create!, content: "Schedule me")
    scheduled_for = 3.days.from_now.to_date

    card.schedule!(scheduled_on: scheduled_for)

    assert_not_nil card.triaged_at
    assert_equal scheduled_for, card.scheduled_on
  end

  test "direct update resolves project by name" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Direct update")

    card.update!(project_name: "Projects")

    assert_equal "projects", card.reload.project.name
  end

  test "blank project_name clears project" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Clear project")
    card.update!(project_name: "Inbox")

    card.update!(project_name: "")

    assert_nil card.reload.project
  end

  test "auto_archivable excludes pinned bullets" do
    due_unpinned = @user.bullets.create!(bulletable: Task.create!, content: "Due", archives_on: Date.yesterday)
    due_pinned = @user.bullets.create!(bulletable: Task.create!, content: "Pinned due", archives_on: Date.yesterday, pinned: true)

    ids = Bullet.auto_archivable.pluck(:id)

    assert_includes ids, due_unpinned.id
    assert_not_includes ids, due_pinned.id
  end

  test "scheduled_on_date includes bullets scheduled on that day" do
    target_day = 2.days.from_now.to_date
    card = @user.bullets.create!(bulletable: Task.create!, content: "Scheduled", scheduled_on: target_day)
    card.update_columns(created_at: 3.days.ago, updated_at: 3.days.ago)

    ids = @user.bullets.scheduled_on_date(target_day).pluck(:id)

    assert_includes ids, card.id
  end

  test "scheduled_on_date excludes bullets scheduled on another day" do
    day = Date.current
    card = @user.bullets.create!(bulletable: Task.create!, content: "Later", scheduled_on: day + 1)
    card.update_columns(created_at: day.beginning_of_day + 1.hour, updated_at: day.beginning_of_day + 1.hour)

    ids = @user.bullets.scheduled_on_date(day).pluck(:id)

    assert_not_includes ids, card.id
  end

  test "triage_on_date excludes bullets scheduled on another day" do
    day = Date.current
    card = @user.bullets.create!(bulletable: Task.create!, content: "Review later", scheduled_on: day + 1)
    card.update_columns(created_at: day.beginning_of_day + 1.hour, updated_at: day.beginning_of_day + 1.hour)

    ids = @user.bullets.triage_on_date(day).pluck(:id)

    assert_not_includes ids, card.id
  end

  test "scheduled_on_date excludes bullets created today with future scheduled_on" do
    day = Date.current
    card = @user.bullets.create!(bulletable: Task.create!, content: "Hidden in today", scheduled_on: day + 2)
    card.update_columns(created_at: day.beginning_of_day + 2.hours, updated_at: day.beginning_of_day + 2.hours)

    ids = @user.bullets.scheduled_on_date(day).pluck(:id)

    assert_not_includes ids, card.id
  end

  test "scheduled_on_date returns unique bullets for unscheduled created bullets" do
    day = Date.current
    card = @user.bullets.create!(bulletable: Event.create!, content: "Same day")
    card.update_columns(created_at: day.beginning_of_day + 1.hour, updated_at: day.beginning_of_day + 1.hour)

    ids = @user.bullets.scheduled_on_date(day).where(id: card.id).pluck(:id)

    assert_equal [card.id], ids
  end

  test "auto_archivable includes stale untriaged bullets" do
    stale = @user.bullets.create!(bulletable: Task.create!, content: "Stale")
    stale.update_columns(created_at: 8.days.ago, updated_at: 8.days.ago)

    fresh = @user.bullets.create!(bulletable: Task.create!, content: "Fresh")
    fresh.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)

    triaged = @user.bullets.create!(bulletable: Task.create!, content: "Triaged", triaged_at: Time.current)
    triaged.update_columns(created_at: 10.days.ago, updated_at: 10.days.ago)

    ids = Bullet.auto_archivable.pluck(:id)

    assert_includes ids, stale.id
    assert_not_includes ids, fresh.id
    assert_not_includes ids, triaged.id
  end

  test "context card must belong to same user" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Bullet")
    outsider = users(:two)
    outsider_context = outsider.bullets.create!(bulletable: Note.create!, content: "Outside")

    card.context_bullet = outsider_context

    assert_not card.valid?
    assert_includes card.errors[:context_bullet], "must belong to the same user"
  end

  test "context card cannot point to itself" do
    card = @user.bullets.create!(bulletable: Task.create!, content: "Self")

    card.context_bullet = card

    assert_not card.valid?
    assert_includes card.errors[:context_bullet], "can't point to itself"
  end

  test "create_with_bulletable composes and persists delegated type" do
    card = Bullet.create_with_bulletable(
      user: @user,
      bulletable_type: "task",
      card_attributes: {content: "Factory card"},
      bulletable_attributes: {}
    )

    assert_predicate card, :persisted?
    assert_instance_of Task, card.bulletable
  end

  test "create_with_bulletable returns invalid card for unknown type" do
    card = Bullet.create_with_bulletable(
      user: @user,
      bulletable_type: "unknown",
      card_attributes: {content: "Invalid factory card"},
      bulletable_attributes: {}
    )

    assert_not_predicate card, :persisted?
    assert_includes card.errors[:bulletable_type], "is not included in the list"
  end

  test "type_capabilities resolves known type safely" do
    assert_equal({temporal: true, completable: true}, Bullet.type_capabilities("task"))
  end

  test "type_capabilities falls back to defaults for unknown type" do
    assert_equal Bulletable::DEFAULT_CAPABILITIES, Bullet.type_capabilities("unknown")
  end
end
