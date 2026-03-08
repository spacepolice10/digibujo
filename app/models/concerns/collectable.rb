module Collectable
  extend ActiveSupport::Concern
  include Promotable

  def collect_as_note!(tag_names: [])
    promote_to! Note.new, tag_names: tag_names
  end
end
