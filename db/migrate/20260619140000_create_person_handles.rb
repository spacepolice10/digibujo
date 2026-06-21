# frozen_string_literal: true

class CreatePersonHandles < ActiveRecord::Migration[8.1]
  class MigrationPersonHandle < ApplicationRecord
    self.table_name = "person_handles"
  end

  def up
    create_table :person_handles do |t|
      t.references :person, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.string :platform
      t.string :data, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    now = Time.current
    rows = []

    Person.find_each do |person|
      position = 0

      if person.read_attribute(:email).present?
        rows << {
          person_id: person.id,
          kind: 0,
          platform: nil,
          data: person.read_attribute(:email),
          position: position,
          created_at: now,
          updated_at: now
        }
        position += 1
      end

      if person.read_attribute(:number).present?
        rows << {
          person_id: person.id,
          kind: 1,
          platform: nil,
          data: person.read_attribute(:number),
          position: position,
          created_at: now,
          updated_at: now
        }
      end
    end

    MigrationPersonHandle.insert_all(rows) if rows.any?

    remove_column :people, :email, :string
    remove_column :people, :number, :string
  end

  def down
    add_column :people, :email, :string
    add_column :people, :number, :string

    Person.reset_column_information

    Person.find_each do |person|
      handles = MigrationPersonHandle.where(person_id: person.id).order(:position, :id)
      email = handles.find { |handle| handle.kind == 0 }&.data
      phone = handles.find { |handle| handle.kind == 1 }&.data
      person.update_columns(email: email, number: phone)
    end

    drop_table :person_handles
  end
end
