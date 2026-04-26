module Cardable
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :cardable, dependent: :destroy
  end

  class_methods do
    def capabilities
      @capabilities ||= new.capabilities.freeze
    end

    def icon
      raise NotImplementedError, "#{self} must define .icon"
    end

    def colour
      raise NotImplementedError, "#{self} must define .colour"
    end

    def name
      raise NotImplementedError, "#{self} must define .name"
    end

    def marker
      raise NotImplementedError, "#{self} must define .marker"
    end
  end

  def temporal?    = false
  def completable? = false
  def icon   = self.class.icon
  def colour = self.class.colour
  def name   = self.class.name
  def marker = self.class.marker
  def excerpt = ""
  def capabilities
    { temporal: temporal?, completable: completable? }
  end
end
