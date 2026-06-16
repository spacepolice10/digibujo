# frozen_string_literal: true

# Navigation hub: projects, collections, monthly spreads, future log, and recent activity.
class HomeController < ApplicationController
  include UserCollections

  COLLECTIONS_LIMIT = 8

  def show
    @projects = recent_projects
    @collections = user_collections.limit(COLLECTIONS_LIMIT)
    @future = future_bucket
    @monthly_buckets = recent_monthly_buckets
    @activities = recent_activities
    @today_count = today_bullets_count
    @section_open = section_open_state
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

  def section_open_state
    User::Settings::SECTIONS.index_with { |key| Current.user.settings!.section_open?(key) }
  end
end
