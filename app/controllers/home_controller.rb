# frozen_string_literal: true

# Navigation hub: projects, collections, monthly spreads, and future log.
class HomeController < ApplicationController
  COLLECTIONS_LIMIT = 8
  PUBLISHED_LIMIT = 8

  def show
    @projects = recent_projects
    @collections = Current.user.active_collections.limit(COLLECTIONS_LIMIT)
    @show_collections_more = Current.user.active_collections.count > COLLECTIONS_LIMIT
    @published_bullets = published_bullets_preview
    @show_published_more = published_bullets_scope.count > PUBLISHED_LIMIT
    @people = recent_people
    @future = Current.user.future_buckets.first&.bucket
    @future_monthly_buckets = Current.user.future_buckets.first&.monthly_buckets&.includes(:bucket) || MonthlyBucket.none
    @daylog_bullets_number = daylog_bullets_number
    @recurrencies = Current.user.recurrencies.chronological
    @recurrency_tracker = RecurrencyTracker.new(
      user: Current.user,
      from: Date.current.beginning_of_month,
      to: Date.current.end_of_month
    )
    @section_expanded_status = section_expanded_status
  end

  private

  def recent_projects
    Current.user.projects.first(8)
  end

  def recent_people
    Current.user.people.first(8)
  end

  def daylog_bullets_number
    Current.user.bullets.where(pops_on: Date.current).active.count
  end

  def published_bullets_scope
    Current.user.bullets.published
      .includes(:published_entity)
      .preload(bulletable: :rich_text_body)
      .order(published_entities: { published_at: :desc })
  end

  def published_bullets_preview
    published_bullets_scope.limit(PUBLISHED_LIMIT)
  end

  def section_expanded_status
    User::Settings::SECTION_COLUMNS.transform_values { |column| Current.user.settings![column] }
  end
end
