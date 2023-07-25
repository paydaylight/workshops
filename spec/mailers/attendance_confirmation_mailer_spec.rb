# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AttendanceConfirmationMailer do
  include Rails.application.routes.url_helpers

  let(:event) { create(:event) }

  describe '.remind' do
    subject { described_class.remind(invitation_id: invitation.id).deliver_now }

    let(:invitation) { create(:invitation, membership: create(:membership, event: event)) }

    it 'sends email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'has confirm attendance URL' do
      subject

      expect(ActionMailer::Base.deliveries.last.body).to include(rsvp_confirm_attendance_url(invitation.code))
    end
  end

  describe '.alert_staff' do
    subject { described_class.alert_staff(event_id: event.id).deliver_now }

    let(:membership) { create(:membership, attendance: 'Confirmed', role: 'Participant', event: event) }

    before do
      create(:user, :staff, location: event.location)
      create(:invitation, membership: membership)
    end

    it 'sends email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    describe 'participants who did not confirm attendance' do
      it 'has count' do
        subject

        expect(ActionMailer::Base.deliveries.last.body).to include('has total 1 confirmed members')
      end

      it 'has emails' do
        subject

        expect(ActionMailer::Base.deliveries.last.body).to include(membership.person.email)
      end
    end
  end
end
