module Cardable
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :cardable, dependent: :destroy
  end

  class_methods do
    def capabilities
      @capabilities ||= new.capabilities.freeze
    end
  end

  def temporal?    = false
  def completable? = false
  def taggable?    = true

  def capabilities
    { temporal: temporal?, completable: completable?, taggable: taggable? }
  end
end
