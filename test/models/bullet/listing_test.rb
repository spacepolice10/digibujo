# frozen_string_literal: true

require 'test_helper'

class Bullet::ListingTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @user = users(:one)
    @project = create_project!(@user, name: 'alpha')
    @person = @user.people.create!(name: 'ada')
    @collection = create_collection!(@user, name: 'inbox')
    @params = ActionController::Parameters.new({})
  end

  test 'project context lists active tagged bullets' do
    tagged = create_bullet!(body: 'Tagged task')
    tagged.bullet_projects.create!(project: @project)
    create_bullet!(body: 'Untagged task')

    listing = Bullet::Listing.for(user: @user, context: @project, params: @params)

    assert_equal [tagged], listing.relation.to_a
  end

  test 'person context lists active tagged bullets' do
    tagged = create_bullet!(body: 'Tagged task')
    tagged.bullet_people.create!(person: @person)
    create_bullet!(body: 'Other task')

    listing = Bullet::Listing.for(user: @user, context: @person, params: @params)

    assert_equal [tagged], listing.relation.to_a
  end

  test 'collection context lists active bullets in bucket' do
    collected = create_bullet!(body: 'Collected', bucket_id: @collection.bucket.id)
    create_bullet!(body: 'Timeline')

    listing = Bullet::Listing.for(user: @user, context: @collection, params: @params)

    assert_equal [collected], listing.relation.to_a
  end

  test 'sprint context lists active bullets in bucket' do
    sprint = create_sprint!(
      @user,
      name: 'launch',
      starts_on: Date.current,
      ends_on: Date.current + 6.days
    )
    collected = create_bullet!(body: 'Collected', bucket_id: sprint.bucket.id)
    create_bullet!(body: 'Timeline')

    listing = Bullet::Listing.for(user: @user, context: sprint, params: @params)

    assert_equal [collected], listing.relation.to_a
    assert_equal sprint_path(sprint), listing.path
  end

  test 'type filter narrows to bulletable type' do
    task = create_bullet!(body: 'Task line')
    task.bullet_projects.create!(project: @project)
    event = create_bullet!(body: 'Event line', bulletable: Event.create!)
    event.bullet_projects.create!(project: @project)

    listing = Bullet::Listing.for(
      user: @user,
      context: @project,
      params: ActionController::Parameters.new(type: 'task')
    )

    assert_equal [task], listing.relation.to_a
    assert_equal 'Task', listing.type
  end

  test 'type ignores unknown values' do
    bullet = create_bullet!(body: 'Tagged task')
    bullet.bullet_projects.create!(project: @project)

    listing = Bullet::Listing.for(
      user: @user,
      context: @project,
      params: ActionController::Parameters.new(type: 'evil')
    )

    assert_equal [bullet], listing.relation.to_a
    assert_nil listing.type
  end

  test 'excludes archived bullets' do
    archived = create_bullet!(body: 'Done')
    archived.bullet_projects.create!(project: @project)
    archived.archive!

    listing = Bullet::Listing.for(user: @user, context: @project, params: @params)

    assert_empty listing.relation
  end

  test 'unsupported context raises' do
    listing = Bullet::Listing.for(user: @user, context: @user, params: @params)

    assert_raises(ArgumentError) { listing.relation }
    assert_raises(ArgumentError) { listing.path }
  end

  test 'path builds context urls with optional type and page' do
    listing = Bullet::Listing.for(
      user: @user,
      context: @project,
      params: ActionController::Parameters.new(type: 'task', page: '2')
    )

    assert_equal project_path(@project), listing.path(type: nil)
    assert_equal project_path(@project, type: 'task'), listing.path
    assert_equal project_path(@project, type: 'note'), listing.path(type: 'note')
    assert_equal project_path(@project, type: 'task', page: '3'), listing.path(page: '3')
  end

  test 'filters include all bulletable types' do
    listing = Bullet::Listing.for(user: @user, context: @project, params: @params)

    assert_equal [ nil, 'All', 'list', nil ], listing.filters.first
    assert_equal Bullet.bulletable_types.size + 1, listing.filters.size
  end

  private

  def create_bullet!(body:, bulletable: Task.create!, **attrs)
    @user.bullets.create!(bulletable: bulletable, body: body, **attrs)
  end
end
