# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Que::DoubleCheckAttendanceJob, type: :job do
  let(:event) do
    create(
      :event,
      start_date: start_date,
      end_date: end_date,
      max_virtual: 10,
      max_participants: 10,
      event_format: 'Hybrid'
    )
  end
  let(:start_date) { 3.month.since(Date.today) }
  let(:end_date) { start_date + 5.days }

  def create_membership(role, attendance: 'Confirmed')
    create(:membership, role: role, attendance: attendance, event: event)
  end

  let(:participant_invitation) do
    create(:invitation, membership: create_membership('Participant'))
  end

  let(:organizer_invitation) do
    create(:invitation, membership: create_membership('Organizer'))
  end

  let(:contact_organizer_invitation) do
    create(:invitation, membership: create_membership('Contact Organizer'))
  end

  before do
    participant_invitation
    organizer_invitation
    contact_organizer_invitation
    create(:invitation, membership: create_membership('Virtual Participant'))
    create_membership('Participant')
    create(:invitation, membership: create_membership('Participant', attendance: 'Undecided'))
  end

  describe '.enqueue' do
    context 'when error' do
      subject { described_class.run(event_id: event.id) }

      before do
        allow(AttendanceConfirmationMailer).to receive(:remind).and_raise(ActiveRecord::RecordNotFound)
        allow(StaffMailer).to receive(:notify_sysadmin).and_call_original
      end

      it 'sends error report to sysadmin' do
        subject

        expect(StaffMailer).to have_received(:notify_sysadmin)
      end
    end

    describe 'step: :rsvp_one_month_before_event' do
      subject { described_class.run(event_id: event.id, step: :rsvp_one_month_before_event) }

      it 'reminds confirmed members about upcoming workshop' do
        subject

        expect(ActionMailer::Base.deliveries.count).to eq(3)
      end

      it 'schedules next step' do
        expect { subject }.to change { QueJobs.count }.by(1)
      end

      it 'schedules step: :rsvp_two_weeks_before_event' do
        allow(described_class).to receive(:enqueue)

        subject

        expect(described_class).to have_received(:enqueue)
          .with(
            event_id: event.id,
            step: :rsvp_two_weeks_before_event,
            job_options: { run_at: event.two_weeks_before_start }
          )
      end
    end

    describe 'step: :rsvp_two_weeks_before_event' do
      subject { described_class.run(event_id: event.id, step: :rsvp_two_weeks_before_event) }

      it 'reminds confirmed members who did not replied in step before' do
        participant_invitation.delete

        subject

        expect(ActionMailer::Base.deliveries.count).to eq(2)
      end

      it 'schedules next step' do
        expect { subject }.to change { QueJobs.count }.by(1)
      end

      it 'schedules step: :alert_staff' do
        allow(described_class).to receive(:enqueue)

        subject

        expect(described_class).to have_received(:enqueue)
          .with(
            event_id: event.id,
            step: :alert_staff,
            job_options: { run_at: event.one_week_before_start }
          )
      end
    end

    describe 'step: :alert_staff' do
      subject { described_class.run(event_id: event.id, step: :alert_staff) }

      context 'when there are still members who did not RSVP' do
        it 'sends out email to staff' do
          allow(AttendanceConfirmationMailer).to receive(:alert_staff)

          subject

          expect(AttendanceConfirmationMailer).to have_received(:alert_staff).with(event_id: event.id)
        end
      end

      context 'when all members RSVP' do
        before do
          participant_invitation.delete
          organizer_invitation.delete
          contact_organizer_invitation.delete
        end

        it 'does not notify staff' do
          expect { subject }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end

    context 'when unknown step' do
      subject { described_class.run(event_id: event.id, step: :non_existing) }

      it 'sends email to sysadmin' do
        allow(StaffMailer).to receive(:notify_sysadmin).and_call_original

        subject

        expect(StaffMailer).to have_received(:notify_sysadmin)
      end
    end
  end
end
