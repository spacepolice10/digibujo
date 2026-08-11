# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/migrate/20260621120300_flatten_bundles_to_collections.rb")

class FlattenBundlesToCollectionsTest < ActiveSupport::TestCase
  parallelize(workers: 1)
  self.use_transactional_tests = false

  setup do
    @user = users(:one)
    @snapshot_bucket_ids = @user.buckets.pluck(:id)
    @snapshot_bullet_ids = @user.bullets.pluck(:id)
    @parent_collection = create_collection!(@user, name: "parent")
    ensure_bundles_table!
  end

  teardown do
    Bullet.where(user_id: @user.id).where.not(id: @snapshot_bullet_ids).destroy_all
    Bucket.where(user_id: @user.id).where.not(id: @snapshot_bucket_ids).find_each(&:destroy)
    ensure_bundles_table!
  end

  test "bundles table is removed after migration" do
    FlattenBundlesToCollections.new.up

    assert_not ActiveRecord::Base.connection.table_exists?(:bundles)
  end

  test "migrates bundle bullets pins and search records into a new collection" do
    bundle_name = "bundle-subfolder-#{SecureRandom.hex(4)}"
    _bundle_id, old_bucket_id = insert_bundle!(name: bundle_name, colour: "teal")
    bullet = create_bullet!(@user,
      bulletable: Task.new, body: "In bundle",
      bucket_id: old_bucket_id,
      pops_on: nil
    )
    @user.pinned_entities.create!(pinnable_type: "Bucket", pinnable_id: old_bucket_id)
    Search::Record.upsert!(
      user_id: @user.id,
      searchable_type: "Bucket",
      searchable_id: old_bucket_id,
      search_name: bundle_name,
      search_body: bundle_name
    )

    FlattenBundlesToCollections.new.up

    bullet.reload
    new_bucket = bullet.bucket
    assert_equal "Collection", new_bucket.bucketable_type
    assert_equal bundle_name, new_bucket.name
    assert @user.pinned_entities.exists?(pinnable_type: "Bucket", pinnable_id: new_bucket.id)
    assert Search::Record.exists?(searchable_type: "Bucket", searchable_id: new_bucket.id)
    assert_not Bucket.exists?(old_bucket_id)
  end

  test "disambiguates collection name when bundle name collides with an existing bucket" do
    create_collection!(@user, name: "notes")
    _bundle_id, _old_bucket_id = insert_bundle!(name: "notes")

    FlattenBundlesToCollections.new.up

    names = @user.buckets.where(bucketable_type: "Collection").order(:id).pluck(:name)
    assert_includes names, "notes"
    assert_includes names, "notes 2"
  end

  private

  def ensure_bundles_table!
    return if ActiveRecord::Base.connection.table_exists?(:bundles)

    ActiveRecord::Base.connection.create_table :bundles do |t|
      t.integer :user_id, null: false
      t.integer :collection_id, null: false
      t.timestamps
    end
  end

  def insert_bundle!(name:, colour: nil)
    now = Time.current.to_fs(:db)
    bundle_id = ActiveRecord::Base.connection.insert(<<~SQL.squish)
      INSERT INTO bundles (user_id, collection_id, created_at, updated_at)
      VALUES (#{@user.id}, #{@parent_collection.id}, '#{now}', '#{now}')
    SQL

    colour_sql = colour ? "'#{colour}'" : "NULL"
    bucket_id = ActiveRecord::Base.connection.insert(<<~SQL.squish)
      INSERT INTO buckets (user_id, bucketable_type, bucketable_id, name, colour, pinned, created_at, updated_at)
      VALUES (#{@user.id}, 'Bundle', #{bundle_id}, '#{name}', #{colour_sql}, 0, '#{now}', '#{now}')
    SQL

    [bundle_id, bucket_id]
  end
end
