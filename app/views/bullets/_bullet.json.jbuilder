# frozen_string_literal: true

json.id bullet.id
json.bulletable_type bullet.bulletable_type
json.pops_on bullet.pops_on
json.bucket_id bullet.bucket_id
json.pinned bullet.pinned?
json.archived bullet.archived?
json.migrated_at bullet.migrated_at
json.author_name bullet.author_name
json.body bullet.body_as_text
json.body_html bullet.body.to_s
json.created_at bullet.created_at
json.updated_at bullet.updated_at
json.url bullet_url(bullet)

case bullet.bulletable_type
when 'Task'
  json.completed bullet.completed?
when 'Event'
  json.starts_date bullet.starts_date
  json.ends_date bullet.ends_date
when 'Voice'
  json.duration_seconds bullet.bulletable.duration_seconds
end
