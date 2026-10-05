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

  test "keeps bullets when an expired archived collection is destroyed" do
    collection = create_collection!(@user, name: "Stale with bullets")
    bullet = create_bullet!(@user, body: "Stays", collection: collection)
    expire!(collection)

    assert_difference -> { Collection.count }, -1 do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert Bullet.exists?(bullet.id)
    assert_empty bullet.reload.collections
  end

  test "destroys expired archived bullets" do
    bullet = create_bullet!(@user, body: "Old news")
    expire!(bullet)

    assert_difference -> { Bullet.count }, -1 do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  test "keeps recently archived collections" do
    collection = create_collection!(@user, name: "Fresh archive")
    collection.archive!

    assert_no_difference -> { Collection.count } do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert collection.reload.archived?
  end

  test "purges old unattached blobs" do
    blob = create_blob!(filename: "orphan.png", content_type: "image/png")
    blob.update!(created_at: 3.days.ago)

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  test "keeps recent unattached blobs" do
    create_blob!(filename: "fresh.png", content_type: "image/png")

    assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
      CleanSoftDeletedRecordsJob.perform_now
    end
  end

  private

  def expire!(record)
    record.archive!
    record.archive.update!(created_at: (Archivable::RETENTION_DAYS + 1).days.ago)
  end
end
