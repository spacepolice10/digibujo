module Bulletable
  extend ActiveSupport::Concern

  included do
    has_one :bullet, as: :bulletable, dependent: :destroy
  end

  def temporal?    = false
  def completable? = false
  def excerpt = ""
  def name = ""
end
