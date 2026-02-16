module Cardable
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :cardable, dependent: :destroy
  end
end
