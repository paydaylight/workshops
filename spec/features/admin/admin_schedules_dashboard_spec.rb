# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

RSpec.describe 'Admin Schedules Dashboard', type: :feature do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, code: '23w222') }

  def fill_in_form(location: 'Room 1')
    select '23w222', from: 'Event'
    fill_in 'Start time', with: event.start_date + 1.hour
    fill_in 'End time', with: event.start_date + 1.day
    fill_in 'Name', with: 'Day 1 schedule'
    select location, from: 'Location'
    fill_in 'Updated by', with: admin.name
  end

  after(:each) do
    Warden.test_reset!
  end

  before do
    event
    create(:location, name: 'Room 1')
    create(:location, name: 'Room 2')

    login_as admin, scope: :user
    visit admin_schedules_path
  end

  describe 'creating a schedule' do
    before do
      click_link('New schedule')
      fill_in_form
      click_on 'Create Schedule'

      visit admin_schedules_path
    end

    it { expect(page).to have_content('Day 1 schedule') }
  end

  context 'when location changes' do
    let(:schedule) { create(:schedule, location: location.name) }
    let(:location) { create(:location, name: 'Old location') }

    before { schedule }

    context 'when updated' do
      before do
        location.update_attribute(:name, 'New location')
        visit edit_admin_schedule_path(schedule.id)
      end

      it('still shows previous value') { expect(page.has_select?('Location', selected: schedule.location)) }
      it { expect(schedule.location).not_to eq(location.reload) }
    end

    context 'when deleted' do
      before do
        location.delete
        visit edit_admin_schedule_path(schedule.id)
      end

      it('still shows previous value') { expect(page.has_select?('Location', selected: 'Old location')) }
    end
  end
end
