# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require "rails_helper"
include ActiveJob::TestHelper

RSpec.describe StaffMailer, type: :mailer do
  before :each do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  after(:each) do
    ActionMailer::Base.deliveries.clear
  end

  describe '.event_sync' do
    before do
      @event = FactoryGirl.create(:event, code: '15w6661')
    end

    before :each do
      @sync_errors = { 'Event' => @event, 'People' => Array.new, 'Memberships' => Array.new }
      StaffMailer.event_sync(@sync_errors).deliver_now
    end

    it 'sends email' do
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it 'To: program coordinator' do
      expect(ActionMailer::Base.deliveries.first.to).to include(Global.email.program_coordinator)
    end

    it 'Cc: system administrator' do
      expect(ActionMailer::Base.deliveries.first.cc).to include(Global.email.system_administrator)
    end
  end

  describe '.schedule_change' do

    let(:event) { build(:event) }
    let(:original_schedule) { build(:schedule) }
    let(:new_schedule) { build(:schedule, name: 'New name') }

    before :each do
      StaffMailer.schedule_change(original_schedule, new_schedule).deliver_now
    end

    it 'sends email' do
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it 'To: schedule_staff' do
      expect(ActionMailer::Base.deliveries.first.to).to match_array(Global.email.schedule_staff.split(', '))
    end

    it 'Cc: system administrator' do
      expect(ActionMailer::Base.deliveries.first.cc).to include(Global.email.system_administrator)
    end
  end
end
