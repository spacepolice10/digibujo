module Completable
  extend ActiveSupport::Concern

  def done?
    completable? && cardable.done?
  end
end
