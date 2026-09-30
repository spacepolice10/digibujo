# frozen_string_literal: true

# Renders the signed-in user's navigation hub and compact previews.
class HomeController < ApplicationController
  PREVIEW_LIMIT = 3

  def show
    @collections = collections
    @attachments = attachments
    @projects = projects
    @published_bullets = published_bullets
  end

  private

  def collections
    Current.user.collections.active.order(created_at: :desc).limit(PREVIEW_LIMIT)
  end

  def attachments = User::Attachments.new(Current.user).attachments.limit(PREVIEW_LIMIT)
  def projects = Current.user.projects.order(created_at: :desc).limit(PREVIEW_LIMIT)

  def published_bullets
    Current.user.bullets.published
           .includes(:published_entity)
           .preload(:bulletable)
           .order(published_entities: { published_at: :desc })
           .limit(PREVIEW_LIMIT)
  end
end
