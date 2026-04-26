module CollectionAssignable
  extend ActiveSupport::Concern

  included do
    attribute :collection_name, :string

    after_initialize do
      unless collection_name_changed?
        self.collection_name = collection&.name.to_s
        clear_attribute_changes([:collection_name])
      end
    end

    before_save :assign_collection, if: -> { collection_name_changed? }
  end

  private

  def assign_collection
    normalized_name = normalize_collection_name(collection_name)

    if normalized_name.blank?
      self.collection = nil
      return
    end

    self.collection = find_or_create_collection_by_name!(normalized_name)
  end

  def find_or_create_collection_by_name!(normalized_name)
    user.collections.find_or_create_by!(name: normalized_name)
  end

  def normalize_collection_name(name)
    name.to_s.strip.downcase
  end
end
