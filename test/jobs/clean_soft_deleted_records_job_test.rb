# frozen_string_literal: true

require "test_helper"

class CleanSoftDeletedRecordsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
  end

  test "destroys expired archived collection buckets" do
    collection = create_collection!(@user, name: "Stale")
    bucket = collection.bucket
    bucket.archive!
    bucket.archive.update!(created_at: (Archivable::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Bucket.count }, -1 do
      assert_difference -> { Collection.count }, -1 do
        CleanSoftDeletedRecordsJob.perform_now
      end
    end
  end

  test "destroys bullets with expired archived collection buckets" do
    collection = create_collection!(@user, name: "Stale with bullets")
    bucket = collection.bucket
    bullet = create_bullet!(@user, bulletable: Task.new, body: "Goes away", bucket: bucket)
    bucket.archive!
    bucket.archive.update!(created_at: (Archivable::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Bullet.count }, -1 do
      CleanSoftDeletedRecordsJob.perform_now
    end

    assert_not Bullet.exists?(bullet.id)
  end

  test "records destroyed activity that survives the bucket" do
    collection = create_collection!(@user, name: "Stale")
    bucket = collection.bucket
    bucket_id = bucket.id
    bucket_name = bucket.name
    bucket.archive!
    bucket.archive.update!(created_at: (Archivable::RETENTION_DAYS + 1).days.ago)

    assert_difference -> { Activity.where(action: "destroyed").count }, 1 do
      CleanSoftDeletedRecordsJob.perform_now
    end

    activity = Activity.where(action: "destroyed", subject_type: "Bucket", subject_id: bucket_id).last
    assert_equal "Collection", activity.metadata["bucketable_type"]
    assert_equal bucket_name, activity.metadata["name"]
    assert_nil activity.subject
  end

  test "keeps pinned archived collection buckets past retention" do
    collection = create_collection!(@user, name: "Pinned stale")
    bucket = collection.bucket
    bucket.archive!
    bucket.archive.update!(created_at: (Archivable::RETENTION_DAYS + 1).days.ago)
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
