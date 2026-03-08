class Draft < ApplicationRecord
  include Cardable
  include Schedulable
  include Collectable

  def form_fields = []
end
