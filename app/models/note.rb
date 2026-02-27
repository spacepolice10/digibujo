class Note < ApplicationRecord
  include Cardable

  def form_fields = [:tag_picker]
end
