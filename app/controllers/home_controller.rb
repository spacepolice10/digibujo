# frozen_string_literal: true

# Navigation hub: projects, collections, monthly spreads, future log, and recent activity.
class HomeController < ApplicationController
  include UserCollections

  COLLECTIONS_LIMIT = 8

  def show
    @projects = recent_projects
    @collections = user_collections.limit(COLLECTIONS_LIMIT)
    @bundles = recent_bundles
    @people = recent_people
    @future = future_bucket
    @monthly_buckets = recent_monthly_buckets
    @activities = recent_activities
    @today_count = today_bullets_count
    @section_expanded_status = section_expanded_status
  end

  private

  def recent_projects
    Current.user.projects.first(8)
  end

  def future_bucket
    Current.user.buckets
           .where(bucketable_type: 'FutureBucket')
           .first
  end

  def recent_people
    Current.user.people.first(8)
  end

  def recent_bundles
    Current.user.bundles.includes(:collection, bucket: :bullets).first(8)
  end

  def recent_monthly_buckets
    Current.user.monthly_buckets.first(8)
  end

  def recent_activities
    Current.user.bullet_activities
           .includes(:bullet)
           .order(created_at: :desc)
           .limit(6)
  end

  def today_bullets_count
    Current.user.bullets.dailylog(Date.current).count
  end

  def section_expanded_status
    User::Settings::SECTION_COLUMNS.transform_values { |column| Current.user.settings![column] }
  end
end
