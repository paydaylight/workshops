# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Que::ReportEventStatisticsJob, type: :job do

  include ActiveSupport::Testing::TimeHelpers

  subject { described_class.run(event_id: event.id) }

  let(:event) { create(:event_with_members) }

  before do
    create(:user, :staff, location: event.location)
  end

  describe '.enqueue' do
    it 'calls EventStatisticsMailer' do
      allow(EventStatisticsMailer).to receive(:notify).and_call_original
      subject
      expect(EventStatisticsMailer).to have_received(:notify).with(event_id: event.id)
    end

    describe 'rescheduling' do
      let(:event) { create(:event_with_members, start_date: start_date, end_date: start_date + 5.days) }
      let!(:que_job) { QueJobs.where("kwargs::jsonb <@ '{\"event_id\": #{event.id}}'::jsonb").last }

      context 'when it is more than 2 month until event start' do
        before do
          travel_to Time.zone.now
        end

        after do
          travel_back
        end

        let(:start_date) { 3.month.from_now(Time.zone.now) }

        it 'reschedules job' do
          expect { subject }.to change { QueJobs.count }.by(1)
        end

        it 'has run_at in 2 month' do
          subject

          expect(que_job.run_at).to eq(2.month.from_now.beginning_of_day)
        end
      end

      context 'when it is less than 2 month until event start' do
        let(:start_date) { 1.month.from_now(Time.zone.now) }

        it 'does not reschedule job' do
          expect { subject }.to change { QueJobs.count }.by(0)
        end
      end
    end
  end

  describe 'participants count' do
    let(:event) { create(:event, event_format: 'Hybrid', max_participants: max_participants, max_virtual: 10) }

    context 'when there are participants spots' do
      let(:max_participants) { 2 }

      before do
        create(:membership, attendance: 'Confirmed', role: 'Participant', event: event)
        # Does not count towards spots left
        create(:membership, attendance: 'Not Yet Invited', role: 'Participant', event: event)
        create(:membership, attendance: 'Invited', role: 'Observer', event: event)
        create(:membership, attendance: 'Undecided', role: 'Virtual Participant', event: event)
      end

      it('sends email') { expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1) }
    end

    context 'when there are no participant spots' do
      let(:max_participants) { 3 }

      before do
        create(:membership, attendance: 'Confirmed', role: 'Participant', event: event)
        create(:membership, attendance: 'Invited', role: 'Organizer', event: event)
        create(:membership, attendance: 'Undecided', role: 'Contact Organizer', event: event)
        # Does not count towards spots left
        create(:membership, attendance: 'Invited', role: 'Observer', event: event)
        create(:membership, attendance: 'Undecided', role: 'Virtual Participant', event: event)
        create(:membership, attendance: 'Not Yet Invited', role: 'Participant', event: event)
      end

      it('does not send email') { expect { subject }.not_to change { ActionMailer::Base.deliveries.count } }
    end
  end
end
