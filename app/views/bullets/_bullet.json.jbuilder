# frozen_string_literal: true

json.id bullet.id
json.bulletable_type bullet.bulletable_type
json.pops_on bullet.pops_on
json.collection_id bullet.collection_id
json.done bullet.done?
json.archived bullet.archived?
json.author_name bullet.author_name
json.body bullet.body_as_text
json.body_html bullet.body.to_s
json.created_at bullet.created_at
json.updated_at bullet.updated_at
json.url bullet_url(bullet)

json.duration_seconds bullet.memo.duration_seconds if bullet.memo?
