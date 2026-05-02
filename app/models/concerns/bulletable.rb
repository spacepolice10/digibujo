module Bulletable
  extend ActiveSupport::Concern
  DEFAULT_CAPABILITIES = { temporal: false, completable: false }.freeze

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy
  end

  class_methods do
    def capabilities
      @capabilities ||= new.capabilities.freeze
    end
  end

  def temporal?    = false
  def completable? = false
  def icon   = self.class.icon
  def colour = self.class.colour
  def marker = self.class.marker
  def name   = self.class.name
  def excerpt = ''

  def capabilities
    { temporal: temporal?, completable: completable? }
  end
end
