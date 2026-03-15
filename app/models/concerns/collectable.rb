module Collectable
  extend ActiveSupport::Concern
  include Promotable

  def collect_as_note!(tags: [])
    promote_to! Note.new, tags: tags
  end
end
