# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require_relative 'test_helpers/dom_assertions'
require_relative 'test_helpers/session_test_helper'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def create_project!(user, name:, colour: nil, **)
      user.projects.create!(name: name, colour: colour)
    end

    def create_collection!(user, name:, colour: nil, icon: nil)
      user.collections.create!(name: name, colour: colour, icon: icon)
    end

    def create_bullet!(user, **attrs)
      user.bullets.create!({ bulletable: Text.new }.merge(attrs))
    end
  end
end
