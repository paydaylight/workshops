# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reports', type: :feature do
  let(:admin) { create(:user, :admin) }
  let(:staff) { create(:user, :staff) }
  let(:super_admin) { create(:user, :super_admin) }
  let(:organizer) { create_user_by_role 'Organizer' }
  let(:participant) { create_user_by_role 'Participant' }
  let(:regular_user) { create(:user) }
  let(:user) { regular_user }
  let(:event) { create(:event_with_members) }

  def create_user_by_role(role)
    new_person = create(:person)
    new_user = create(:user, person: new_person)
    create(:membership, event: event, person: new_person, role: role, attendance: 'Confirmed')

    new_user
  end

  describe 'single event report' do
    before do
      login_as user, scope: :user
      visit event_report_path(event)
    end

    describe 'permissions' do
      context 'when access allowed' do
        before { click_on 'Get report' }

        context 'when admin' do
          let(:user) { admin }

          it { expect(page.response_headers['Content-Type']).to eq('text/csv') }
        end

        context 'when super admin' do
          let(:user) { super_admin }

          it { expect(page.response_headers['Content-Type']).to eq('text/csv') }
        end

        context 'when organizer' do
          let(:user) { organizer }

          it { expect(page.response_headers['Content-Type']).to eq('text/csv') }
        end

        context 'when staff' do
          let(:user) { staff }

          it { expect(page.response_headers['Content-Type']).to eq('text/csv') }
        end
      end

      context 'when access is not allowed' do
        context 'when participant' do
          let(:user) { participant }

          it { expect(page).not_to have_text('Get report') }
          it { expect(page).to have_text('Access denied') }
        end

        context 'when other' do
          it { expect(page).not_to have_text('Get report') }
          it { expect(page).to have_text('Access denied') }
        end
      end
    end

    context 'when event has no members' do
      let(:event) { create(:event) }
      let(:user) { admin }

      before { visit event_report_path(event) }

      it('has a flash with warning') { expect(page).to have_text(I18n.t('ui.flash.empty_event_members')) }
      it('has a disabled form') { expect(page).to have_button('Get report', disabled: true) }
    end

    describe 'selecting fields' do
      let(:user) { admin }
      let(:default_visible_fields) do
        I18n.t('event_report.default_fields').values - ['Attendance', 'Event format', 'Role'] +
          I18n.t('memberships.attendance').values +
          I18n.t('memberships.roles').values +
          I18n.t('events.formats').values
      end
      let(:optional_fields) { I18n.t('event_report.optional_fields').values }

      context 'when default' do
        it 'has checked fields' do
          default_visible_fields.each do |field|
            expect(page).to have_field(field, checked: true)
          end
        end
      end

      context 'when optional' do
        before do
          optional_fields.each do |field|
            check field
          end
        end

        it 'can select optional fields' do
          optional_fields.each do |field|
            expect(page).to have_field(field, checked: true)
          end
        end

        it('works') do
          click_on 'Get report'
          expect(page.response_headers['Content-Type']).to eq('text/csv')
        end
      end
    end
  end

  describe 'global events report' do
    before do
      login_as user, scope: :user
      visit events_report_path
    end

    describe 'permissions' do
      context 'when access allowed' do
        before do
          fill_in :start_date, with: 1.year.ago.to_date
          fill_in :end_date, with: Date.today + 1.day
          click_on 'Get report'
        end

        context 'when admin' do
          let(:user) { admin }

          it { expect(page.response_headers['Content-Type']).to eq('text/csv') }
        end

        context 'when super admin' do
          let(:user) { super_admin }

          it { expect(page.response_headers['Content-Type']).to eq('text/csv') }
        end
      end

      context 'when access is not allowed' do
        context 'when other' do
          it { expect(page).not_to have_text('Get report') }
          it { expect(page).to have_text('Access denied') }
        end

        context 'when staff' do
          let(:user) { staff }

          it { expect(page).not_to have_text('Get report') }
          it { expect(page).to have_text('Access denied') }
        end
      end
    end

    describe 'selecting date' do
      let(:user) { admin }

      context 'when not selected' do
        it { expect(find('#start_date')[:required]).to be_truthy }
        it { expect(find('#end_date')[:required]).to be_truthy }
      end

      context 'when start_date >= end_date' do
        before do
          fill_in :start_date, with: Date.today + 1.day
          fill_in :end_date, with: 1.year.ago.to_date

          click_on 'Get report'
        end

        it { expect(page).to have_text(I18n.t('ui.flash.invalid_date_range')) }
        it { expect(page.response_headers['Content-Type']).not_to eq('text/csv') }
      end

      context 'when start_date < end_date' do
        before do
          fill_in :start_date, with: 1.year.ago.to_date
          fill_in :end_date, with: Date.today + 1.day

          click_on 'Get report'
        end

        it { expect(page.response_headers['Content-Type']).to eq('text/csv') }
      end
    end
  end

  describe 'events summary' do
    let(:user) { admin }

    before do
      login_as user, scope: :user
      visit event_report_path(event)
    end

    def key_to_header(key)
      if EventMembersPresenter::DEFAULT_FIELDS.include?(key)
        I18n.t("event_report.default_fields.#{key}", locale: :en)
      else
        I18n.t("event_report.optional_fields.#{key}", locale: :en)
      end
    end

    context 'when navigating from sidebar' do
      before do
        click_on 'Event Summary'
      end

      it 'shows summary fields' do
        EventMembersPresenter::SUMMARY_FIELDS.each do |field|
          expect(page).to have_text(key_to_header(field))
        end
      end
    end

    context 'when submitting form' do
      before do
        click_on 'See summary'
      end

      let(:event_membership) { event.memberships.first }
      let(:link) { first('.clickable-row')[:'data-href'] }

      it('shows a table') { expect(page.response_headers['Content-Type']).to eq('text/html; charset=utf-8') }

      it 'has a link to edit a membership' do
        expect(link).to eq(edit_event_membership_path(event, event_membership))
      end
    end
  end
end
