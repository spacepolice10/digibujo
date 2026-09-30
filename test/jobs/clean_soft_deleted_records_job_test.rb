# frozen_string_literal: true

require "test_helper"

class CleanSoftDeletedRecordsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "destroys expired archived collections" do
    collection = create_collection!(@user, name: "Stale")
    expire!(collection)

    assert_difference -> { Collection.count }, -1 do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  test "destroys bullets with expired archived collections" do
    collection = create_collection!(@user, name: "Stale with bullets")
    bullet = create_bullet!(@user, body: "Goes away", collection: collection)
    expire!(collection)

    assert_difference -> { Bullet.count }, -1 do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert_not Bullet.exists?(bullet.id)
  end

  test "destroys expired archived bullets" do
    bullet = create_bullet!(@user, body: "Old news")
    expire!(bullet)

    assert_difference -> { Bullet.count }, -1 do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  test "records destroyed activity that survives the collection" do
    collection = create_collection!(@user, name: "Stale")
    collection_id = collection.id
    collection_name = collection.name
    expire!(collection)

    assert_difference -> { Activity.where(action: "destroyed").count }, 1 do
      CleanSoftDeletedRecordsJob.perform_now
    end

    activity = Activity.where(action: "destroyed", subject_type: "Collection", subject_id: collection_id).last
    assert_equal collection_name, activity.metadata["name"]
    assert_nil activity.subject
  end

  test "keeps recently archived collections" do
    collection = create_collection!(@user, name: "Fresh archive")
    collection.archive!

    assert_no_difference -> { Collection.count } do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert collection.reload.archived?
  end

  private

  def expire!(record)
    record.archive!
    record.archive.update!(created_at: (Archivable::RETENTION_DAYS + 1).days.ago)
  end
end
