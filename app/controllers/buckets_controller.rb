# frozen_string_literal: true

class BucketsController < ApplicationController
  def show
    @projects = Current.user.projects.first(8)
    @collections = Current.user.collections.first(8)
  end
end
