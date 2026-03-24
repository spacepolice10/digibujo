module Cardable
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :cardable, dependent: :destroy
  end

  class_methods do
    def capabilities
      @capabilities ||= new.capabilities.freeze
    end

    def form_fields
      @form_fields ||= new.form_fields.freeze
    end

    def icon   = 'pencil'
    def colour = '7'
    def name   = 'Draft'
    def marker = nil
  end

  def temporal?    = false
  def completable? = false
  def taggable?    = true
  def form_fields  = []

  def icon   = self.class.icon
  def colour = self.class.colour
  def name   = self.class.name
  def marker = self.class.marker

  def capabilities
    { temporal: temporal?, completable: completable?, taggable: taggable? }
  end
end
