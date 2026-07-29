# frozen_string_literal: true

json.id @hook.id
json.name @hook.name
json.code @hook.code
json.url hook_intake_url(@hook.code)
json.created_at @hook.created_at
