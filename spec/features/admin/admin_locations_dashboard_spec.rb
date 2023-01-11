# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

RSpec.describe 'Admin Locations Dashboard', type: :feature do
  let(:admin) { create(:user, :admin) }

  def fill_in_form(name: 'Room 1')
    fill_in 'Name', with: name
    fill_in 'Clarification', with: 'Some room'
  end

  after(:each) do
    Warden.test_reset!
  end

  before do
    login_as admin, scope: :user
    visit admin_locations_path
  end

  describe 'creating a location' do
    before do
      click_link('New location')
      fill_in_form
      click_on 'Create Location'

      visit admin_locations_path
    end

    it { expect(page).to have_content('Room 1') }
  end

  describe 'editing a location' do
    let(:location) { create(:location, name: 'Old location') }

    before do
      location
      visit edit_admin_location_path(location.id)
      fill_in_form(name: 'New location')
      click_on 'Update Location'

      visit admin_locations_path
    end

    it { expect(page).to have_content('New location') }
    it { expect(page).not_to have_content('Old location') }
  end
end
