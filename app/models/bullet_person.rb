# frozen_string_literal: true

class BulletPerson < ApplicationRecord
  belongs_to :bullet
  belongs_to :person
end
