module Collectable
  extend ActiveSupport::Concern

  def collect!(collection_id: nil, collection_name: nil)
    attrs = { triaged_at: triaged_at || Time.current }
    attrs[:collection_id] = collection_id unless collection_id.nil?
    attrs[:collection_name] = collection_name unless collection_name.nil?
    update!(attrs)
  end
end
