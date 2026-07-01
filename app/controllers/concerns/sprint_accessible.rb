# frozen_string_literal: true

module SprintAccessible
  extend ActiveSupport::Concern

  included do
    before_action :ensure_sprints_enabled!
  end

  private

  def ensure_sprints_enabled!
    raise ActiveRecord::RecordNotFound unless Sprint.enabled?
  end
end
