# frozen_string_literal: true

# Renders the signed-in user's navigation hub and compact previews.
class HomeController < ApplicationController
  PREVIEW_LIMIT = 3

  def show
    @pinned_entities = pinned_entities
    @collections = collections
    @attachments = attachments
    @projects = projects
    @trackers = trackers
    @published_bullets = published_bullets
  end

  private

  def pinned_entities = Current.user.pinned_entities.order(created_at: :desc).limit(PREVIEW_LIMIT)

  def collections
    Current.user.collections
           .merge(Bucket.active)
           .order('collections.created_at DESC')
           .limit(PREVIEW_LIMIT)
  end

  def attachments = User::Attachments.new(Current.user).attachments.limit(PREVIEW_LIMIT)
  def projects = Current.user.projects.order(created_at: :desc).limit(PREVIEW_LIMIT)

  def trackers
    Current.user.trackers.order(created_at: :desc).limit(PREVIEW_LIMIT).with_completions
  end

  def published_bullets
    Current.user.bullets.published
           .includes(:published_entity)
           .preload(:bulletable)
           .order(published_entities: { published_at: :desc })
           .limit(PREVIEW_LIMIT)
  end
end
