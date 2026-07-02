# frozen_string_literal: true

class Bullet
  class Params
    class TypeRequired < ArgumentError
      def initialize = super('Bullet type is required')
    end

    CREATE_KEYS = %i[pops_on bulletable_type bucket_id].freeze

    def self.resolve_type(name)
      name.to_s.presence_in(Bullet.bulletable_types)
    end

    def self.permit(params, keys: CREATE_KEYS, bullet: nil)
      new(params, bullet: bullet).permit(keys: keys)
    end

    def initialize(params, bullet: nil)
      @params = params
      @bullet = bullet
    end

    def permit(keys: CREATE_KEYS)
      type_class = bulletable_class

      @params.require(:bullet).permit(
        *keys,
        bulletable_attributes: type_class.permitted_bullet_attributes
      ).then { |permitted| ensure_bulletable_defaults!(permitted, type_class) }
    end

    private

    def bulletable_class
      type_name = resolve_type(@params.dig(:bullet, :bulletable_type))
      type_name ||= @bullet&.bulletable_type
      raise TypeRequired if type_name.blank?

      type_name.constantize
    end

    def resolve_type(name)
      self.class.resolve_type(name)
    end

    # accepts_nested_attributes_for :bulletable needs both bulletable_type and
    # bulletable_attributes present, even when the form submits neither.
    def ensure_bulletable_defaults!(permitted, type_class)
      permitted[:bulletable_type] = type_class.name if permitted[:bulletable_type].blank?
      permitted[:bulletable_attributes] = {} if permitted[:bulletable_attributes].blank?
      permitted
    end
  end
end
