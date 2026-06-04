ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def create_project!(user, name:, colour: nil, icon: nil)
      project = Project.create!
      user.buckets.create!(bucketable: project, name: name, colour: colour, icon: icon)
      project
    end

    def create_collection!(user, name:, colour: nil, icon: nil)
      collection = Collection.create!
      user.buckets.create!(bucketable: collection, name: name, colour: colour, icon: icon)
      collection
    end
  end
end
