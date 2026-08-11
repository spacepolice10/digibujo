# frozen_string_literal: true

require 'test_helper'

module Daylogs
  class TriageControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      ensure_daylog!(@user)
      @pending = Pending.provision!(@user)
    end

    test 'show lists pending bullets' do
      bullet = create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new, body: 'From extension',
                                     pops_on: nil)

      get daylog_triage_path

      assert_response :success
      assert_match 'From extension', response.body
      assert_select '.triage--surface .triage--section', count: 2
      assert_select '.triage--section-navigation .button[data-content="text"][aria-label="Back to Daylog"]',
                    text: /Daylog/
      assert_select "##{ActionView::RecordIdentifier.dom_id(bullet, :triage)}[draggable='true']" do
        assert_select '.triage--bullet-actions' do
          assert_select 'form[action=?] button[data-intent="secondary"]' \
                        '[data-size="sm"][data-radius="base"]', daylog_triage_accept_path, text: /Migrate/ do
            assert_select '.icon', count: 1
          end
          assert_select 'form[action=?] button[data-intent="secondary"][data-status="negative"]' \
                        '[data-size="sm"][data-radius="base"]', archive_path, text: /Discard/ do
            assert_select '.icon', count: 1
          end
          assert_select 'button', text: /Postpone/, count: 0
        end
      end
      assert_select '.triage--section[aria-label="Today"] [data-bulk-menu-target="amount"]', count: 0
      assert_select '.triage--section-header [data-bulk-menu-target="menu"]', count: 0
    end

    test 'show lists pending and monthlylog today bullets' do
      monthlylog = create_monthlylog!(@user, name: 'This month')
      create_bullet!(
        @user,
        bucket: monthlylog.bucket,
        bulletable: Task.new, body: 'Monthly today',
        pops_on: Date.current
      )
      create_bullet!(
        @user,
        bucket: monthlylog.bucket,
        bulletable: Task.new, body: 'Monthly tomorrow',
        pops_on: Date.current + 1.day
      )
      create_bullet!(
        @user,
        bucket: monthlylog.bucket,
        bulletable: Note.new, body: 'Monthly unplanned',
        pops_on: nil
      )

      get daylog_triage_path

      assert_response :success
      assert_match 'Monthly today', response.body
      assert_no_match 'Monthly tomorrow', response.body
      assert_no_match 'Monthly unplanned', response.body
    end

    test 'show lists a monthlylog bullet that was scheduled through migration' do
      monthlylog = create_monthlylog!(@user, name: 'This month')
      bullet = create_bullet!(@user, bulletable: Task.new, body: 'Actually scheduled', pops_on: Date.yesterday)
      bullet.postpone!(bucket: monthlylog.bucket, pops_on: Date.current)

      get daylog_triage_path

      assert_response :success
      assert bullet.reload.migrated?
      assert_match 'Actually scheduled', response.body
    end

    test 'expanded preview counts a monthlylog event planned for today' do
      monthlylog = create_monthlylog!(@user, name: 'This month')
      create_bullet!(
        @user,
        bucket: monthlylog.bucket,
        bulletable: Event.new, body: 'Planned appointment',
        pops_on: Date.current
      )

      get daylog_triage_path(preview: :expanded)

      assert_response :success
      assert_select '.daylog--triage-preview .daylog--triage-summary'
      assert_select '.daylog--triage-preview .highlight', text: '1 event'
      assert_select '.daylog--triage-preview .pill--accent', text: /Monthly log/
      assert_no_match(/\b0 (?:tasks|notes|events|voices)\b/, response.body)
    end

    test 'expanded preview describes only populated types for each source' do
      monthlylog = create_monthlylog!(@user, name: 'This month')
      create_bullet!(@user, bucket: monthlylog.bucket, bulletable: Event.new, body: 'Appointment',
                            pops_on: Date.current)
      2.times do |index|
        create_bullet!(@user, bulletable: Task.new, body: "Yesterday task #{index}", pops_on: Date.yesterday)
      end
      create_bullet!(@user, bulletable: Note.new, body: 'Yesterday note', pops_on: Date.yesterday)

      get daylog_triage_path(preview: :expanded)

      assert_response :success
      assert_select '.daylog--triage-preview .highlight', text: '1 event'
      assert_select '.daylog--triage-preview .highlight', text: '2 tasks and 1 note'
      assert_select '.daylog--triage-preview .pill--accent', text: /Monthly log/
      assert_select '.daylog--triage-preview .pill--notify', text: /Yesterday/
      assert_select '.daylog--triage-preview .pill--warning', count: 0
      assert_no_match(/\b0 (?:tasks|notes|events|voices)\b/, response.body)
    end

    test 'expanded preview renders Pending as a source pill' do
      create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new, body: 'Inbox note', pops_on: nil)

      get daylog_triage_path(preview: :expanded)

      assert_response :success
      assert_select '.daylog--triage-preview .highlight', text: '1 note'
      assert_select '.daylog--triage-preview .pill--warning', text: /Pending/
      assert_no_match(/\b0 (?:tasks|notes|events|voices)\b/, response.body)
    end

    test 'show excludes archived bullets' do
      create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new, body: 'Inbox me', pops_on: nil)
      archived = create_bullet!(@user, bucket: @pending.bucket, bulletable: Note.new, body: 'Archived me', pops_on: nil)
      archived.archive!

      get daylog_triage_path

      assert_response :success
      assert_match 'Inbox me', response.body
      assert_no_match 'Archived me', response.body
    end

    test 'show is empty when nothing is pending' do
      get daylog_triage_path

      assert_response :success
      assert_match 'Nothing pending right now', response.body
    end

    test 'show lists bullets left from yesterday' do
      create_bullet!(@user, bulletable: Note.new, body: 'Yesterday unfinished', pops_on: Date.yesterday)

      get daylog_triage_path

      assert_response :success
      assert_match 'Yesterday unfinished', response.body
    end

    test 'preview renders the requested frame state' do
      get daylog_triage_path(preview: :collapsed)

      assert_response :success
      assert_select 'turbo-frame#daylog_triage_preview .layout--flex[data-justify="center"]' do
        assert_select 'a.button[data-turbo-frame="daylog_triage_preview"][aria-label="Open triage"]'
      end

      get daylog_triage_path(preview: :expanded)

      assert_response :success
      assert_select 'turbo-frame#daylog_triage_preview .daylog--triage-preview[data-size="sm"]' do
        assert_select '> .layout--surface[data-elevation="2"][data-padding="true"]'
      end
    end
  end
end
