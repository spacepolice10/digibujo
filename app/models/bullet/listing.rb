# frozen_string_literal: true

class Bullet
  class Listing
    include Rails.application.routes.url_helpers

    def self.for(user:, context:, params:)
      new(user: user, context: context, params: params)
    end

    def initialize(user:, context:, params:)
      @user = user
      @context = context
      @params = params
    end

    def relation
      scope = base_scope.active.distinct
      scope = scope.where(bulletable_type: type) if type.present?
      scope
    end

    def type
      @type ||= @params[:type].to_s.classify.presence_in(Bullet.bulletable_types)
    end

    def type_param
      @params[:type].to_s.presence
    end

    def filters
      [[nil, 'All', 'list', nil]] + Bullet.bulletable_types.map do |bulletable_type|
        [bulletable_type.downcase, bulletable_type.pluralize, bulletable_type.constantize.new.marker_icon,
         bulletable_type.downcase]
      end
    end

    def path(type: :current, page: nil)
      query = {}
      type_value = type == :current ? type_param : type
      query[:type] = type_value if type_value.present?
      query[:page] = page if page.present?

      case @context
      when Project then project_path(@context, **query)
      when Person then person_path(@context, **query)
      when Collection then collection_path(@context, **query)
      when Sprint then sprint_path(@context, **query)
      else
        raise ArgumentError, "unsupported listing context: #{@context.class.name}"
      end
    end

    private

    def base_scope
      case @context
      when Person
        @user.bullets.joins(:people).where(people: { id: @context.id })
      when Project
        @user.bullets.joins(:projects).where(projects: { id: @context.id })
      when Collection
        @user.bullets.where(bucket_id: @context.bucket.id)
      when Sprint
        @user.bullets.where(bucket_id: @context.bucket.id)
      else
        raise ArgumentError, "unsupported listing context: #{@context.class.name}"
      end
    end
  end
end
