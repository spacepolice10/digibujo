# frozen_string_literal: true

require "test_helper"

class CleanSoftDeletedRecordsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "destroys expired archived sprint buckets" do
    sprint = create_sprint!(
      @user,
      name: "Stale",
      starts_on: Date.current - 30.days,
      ends_on: Date.current - 20.days
    )
    bucket = sprint.bucket
    bucket.archive!
    bucket.archive.update!(created_at: (Bucket::Archivable::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Bucket.count }, -1 do
      assert_difference -> { Sprint.count }, -1 do
        CleanSoftDeletedRecordsJob.perform_now
      end
    end
  end

  test "destroys expired archived collection buckets" do
    collection = create_collection!(@user, name: "Stale")
    bucket = collection.bucket
    bucket.archive!
    bucket.archive.update!(created_at: (Bucket::Archivable::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Bucket.count }, -1 do
      assert_difference -> { Collection.count }, -1 do
        CleanSoftDeletedRecordsJob.perform_now
      end
    end
  end

  test "keeps pinned archived collection buckets past retention" do
    collection = create_collection!(@user, name: "Pinned stale")
    bucket = collection.bucket
    bucket.archive!
    bucket.archive.update!(created_at: (Bucket::Archivable::RETENTION_DAYS + 1).days.ago)
    bucket.pin!

    assert_no_difference -> { Bucket.count } do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert bucket.reload.archived?
  end

  test "keeps recently archived collection buckets" do
    collection = create_collection!(@user, name: "Fresh archive")
    bucket = collection.bucket
    bucket.archive!

    assert_no_difference -> { Bucket.count } do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert bucket.reload.archived?
  end
end