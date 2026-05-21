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
  def excerpt = ''
  def name = ''

  def capabilities
    { temporal: temporal?, completable: completable? }
  end
end
