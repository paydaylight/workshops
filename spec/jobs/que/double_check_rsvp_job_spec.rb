# frozen_string_literal: true

require 'rails_helper'

describe Que::DoubleCheckRSVPJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:event) { create(:event, start_date: start_date, end_date: end_date, max_virtual: 10, max_participants: 10) }

  before do
    create(:invitation, membership: create(:membership, role: 'Participant', attendance: 'Confirmed', event: event))
    create(:invitation, membership: create(:membership, role: 'Organizer', attendance: 'Confirmed', event: event))
    create(:invitation, membership: create(:membership, role: 'Contact Organizer', attendance: 'Confirmed', event: event))
    create(:invitation, membership: create(:membership, role: 'Virtual Participant', attendance: 'Confirmed', event: event))
    create(:membership, attendance: 'Confirmed', role: 'Participant', event: event)
    create(:invitation, membership: create(:membership, attendance: 'Undecided', role: 'Participant', event: event))
  end

  describe '.enqueue' do
    subject { described_class.enqueue(event_id: event.id) }

    let(:start_date) { 3.month.since(Date.today) }
    let(:end_date) { start_date + 5.days }

    it 'reminds confirmed members about upcoming workshop' do
      subject
      expect(ActionMailer::Base.deliveries.count).to eq(3)
    end
  end
end
