class Note < ApplicationRecord
  include Cardable

  def form_fields = [:tags_picker]
end
