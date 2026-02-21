class Draft < ApplicationRecord
  include Cardable

  def taggable?
    false
  end
end
