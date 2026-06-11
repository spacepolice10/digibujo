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

    def create_monthlylog!(user, name:, period_from: nil, period_to: nil, colour: nil, icon: nil)
      period = Bucket.monthlylog_period
      monthlylog = Monthlylog.create!
      user.buckets.create!(
        bucketable: monthlylog,
        name: name,
        period_from: period_from || period[:period_from],
        period_to: period_to || period[:period_to],
        colour: colour,
        icon: icon
      )
      monthlylog
    end
  end
end
