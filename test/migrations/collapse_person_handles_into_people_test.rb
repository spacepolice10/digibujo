# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/migrate/20260713125427_collapse_person_handles_into_people")

class CollapsePersonHandlesIntoPeopleTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @user = users(:one)
    build_pre_migration_schema
  end

  teardown do
    drop_temp_tables
  end

  test "copies email and phone from handles then drops person_handles" do
    person_id = insert_person(name: "Ada")
    insert_handle(person_id:, kind: 0, data: "ada@example.com", position: 0)
    insert_handle(person_id:, kind: 1, data: "+15551212", position: 1)

    CollapsePersonHandlesIntoPeople.new.up

    refute @connection.table_exists?(:person_handles)
    row = @connection.select_one("SELECT email, phone FROM people WHERE id = #{person_id}")
    assert_equal "ada@example.com", row["email"]
    assert_equal "+15551212", row["phone"]
  end

  test "down restores person_handles from email and phone" do
    person_id = insert_person(name: "Grace")
    insert_handle(person_id:, kind: 0, data: "grace@example.com", position: 0)
    insert_handle(person_id:, kind: 1, data: "+15559876", position: 1)

    migration = CollapsePersonHandlesIntoPeople.new
    migration.up
    migration.down

    assert @connection.table_exists?(:person_handles)
    handles = @connection.select_all(
      "SELECT kind, data, position FROM person_handles WHERE person_id = #{person_id} ORDER BY position, id"
    ).to_a
    assert_equal [
      { "kind" => 0, "data" => "grace@example.com", "position" => 0 },
      { "kind" => 1, "data" => "+15559876", "position" => 1 }
    ], handles.map { |h| h.slice("kind", "data", "position") }

    people_columns = @connection.columns(:people).map(&:name)
    refute_includes people_columns, "email"
    refute_includes people_columns, "phone"
  end

  private
    def build_pre_migration_schema
      drop_temp_tables

      @connection.create_table :people do |t|
        t.references :user, null: false, foreign_key: true
        t.string :name, null: false
        t.string :colour
        t.string :icon
        t.timestamps
      end

      @connection.create_table :person_handles do |t|
        t.references :person, null: false, foreign_key: true
        t.integer :kind, null: false, default: 0
        t.string :platform
        t.string :data, null: false
        t.integer :position, null: false, default: 0
        t.timestamps
      end
    end

    def drop_temp_tables
      @connection.drop_table :person_handles, if_exists: true
      @connection.drop_table :people, if_exists: true
    end

    def insert_person(name:)
      now = Time.current
      @connection.insert(<<~SQL.squish)
        INSERT INTO people (user_id, name, created_at, updated_at)
        VALUES (#{@user.id}, #{@connection.quote(name)}, #{@connection.quote(now)}, #{@connection.quote(now)})
      SQL
    end

    def insert_handle(person_id:, kind:, data:, position:)
      now = Time.current
      @connection.insert(<<~SQL.squish)
        INSERT INTO person_handles (person_id, kind, data, position, created_at, updated_at)
        VALUES (#{person_id}, #{kind}, #{@connection.quote(data)}, #{position},
                #{@connection.quote(now)}, #{@connection.quote(now)})
      SQL
    end
end
