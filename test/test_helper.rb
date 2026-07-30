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

    def create_tracker!(user, name:, schedule: Tracker::DEFAULT_SCHEDULE.dup, colour: nil, icon: nil)
      user.trackers.create!(name: name, schedule: schedule, colour: colour, icon: icon, start_date: Date.current)
    end

    def create_collection!(user, name:, colour: nil, icon: nil)
      collection = Collection.create!
      user.buckets.create!(bucketable: collection, name: name, colour: colour, icon: icon)
      collection
    end

    def ensure_daylog!(user, _date = Date.current)
      Onboarding.new(user: user).complete
      user.reload.daylog.bucket
    end

    def create_bullet!(user, bucket: nil, bucket_id: nil, **attrs)
      bucket ||= user.buckets.find(bucket_id) if bucket_id
      bucket ||= ensure_daylog!(user)
      attrs = attrs.dup
      attrs[:pops_on] = Date.current if !attrs.key?(:pops_on) && bucket.bucketable_type == 'Daylog'
      user.bullets.create!(bucket: bucket, **attrs)
    end

    def ensure_future!(user, period_from: Date.current.beginning_of_month)
      period_from = period_from.to_date.beginning_of_month
      future = user.futures.find_by(period_from: period_from)
      return future if future&.bucket.present?

      future = user.futures.create!(period_from: period_from)
      user.buckets.create!(
        bucketable: future,
        name: Onboarding::FUTURE_NAME,
        icon: Onboarding::FUTURE_ICON,
        colour: Onboarding::FUTURE_COLOUR
      )
      future
    end

    def create_monthlylog!(user, name:, period_from: nil, colour: nil, icon: nil, **)
      month = (period_from || Date.current).to_date.beginning_of_month

      monthlylog = user.monthlylogs.find_by(period_from: month)
      unless monthlylog
        monthlylog = user.monthlylogs.create!(period_from: month)
      end

      unless monthlylog.bucket
        user.buckets.create!(
          bucketable: monthlylog,
          name: name,
          colour: colour,
          icon: icon
        )
        monthlylog.reload
      end

      monthlylog
    end

  end
end
