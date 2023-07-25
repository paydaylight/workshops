# frozen_string_literal: true

require 'rails_helper'

class QueJobs < ApplicationRecord; end

include ActiveSupport::Testing::TimeHelpers

RSpec.describe Que::ReportEventStatistics, type: :job do

  let(:event) { create(:event) }

  describe '.enqueue' do
    subject { described_class.enqueue(event_id: event.id) }

    it 'calls EventStatisticsMailer' do
      allow(EventStatisticsMailer).to receive(:notify)
      subject
      expect(EventStatisticsMailer).to have_received(:notify).with(event_id: event.id)
    end

    describe 'rescheduling' do
      let(:event) { create(:event, start_date: start_date, end_date: start_date + 5.days) }
      let(:que_job) { QueJobs.where("kwargs::jsonb <@ '{\"event_id\": #{event.id}}'::jsonb").last }

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

        it 'dos not reschedule job' do
          expect { subject }.to change { QueJobs.count }.by(0)
        end
      end
    end
  end
end
