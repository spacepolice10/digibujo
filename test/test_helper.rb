# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require_relative 'test_helpers/session_test_helper'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def create_project!(user, name:, colour: nil, icon: nil)
      user.projects.create!(name: name, colour: colour, icon: icon)
    end

    def create_recurrency!(user, name:, schedule: { "kind" => "daily" }, active_from: nil, active_to: nil, colour: nil, icon: nil)
      user.recurrencies.create!(name: name, schedule: schedule, active_from: active_from, active_to: active_to, colour: colour, icon: icon)
    end

    def create_collection!(user, name:, colour: nil, icon: nil)
      collection = Collection.create!
      user.buckets.create!(bucketable: collection, name: name, colour: colour, icon: icon)
      collection
    end

    def ensure_future_bucket!(user)
      return if user.future_bucket

      future_bucket = FutureBucket.create!(user: user)
      user.buckets.create!(bucketable: future_bucket, name: 'Future Log')
    end

    def create_monthly_bucket!(user, name:, period_from: nil, period_to: nil, colour: nil, icon: nil)
      ensure_future_bucket!(user)
      period = MonthlyBucket.default_period
      monthly_bucket = user.future_bucket.monthly_buckets.create!(
        user: user,
        period_from: period_from || period[:period_from],
        period_to: period_to || period[:period_to]
      )
      user.buckets.create!(
        bucketable: monthly_bucket,
        name: name,
        colour: colour,
        icon: icon
      )
      monthly_bucket
    end
  end
end
