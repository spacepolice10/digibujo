# frozen_string_literal: true

json.array! @hooks do |hook|
  json.id hook.id
  json.name hook.name
  json.code_prefix hook.code_prefix
  json.active hook.active
  json.created_at hook.created_at
end
