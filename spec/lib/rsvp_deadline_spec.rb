# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RsvpDeadline do
  subject(:rsvp_by) { described_class.new(event, invited_on, membership).rsvp_by }

  let(:event) { create(:event, start_date: start_date, end_date: end_date, event_format: 'Hybrid') }
  let(:membership) { create(:membership) }
  let(:invited_on) { DateTime.current }
  let(:end_date) { start_date + 5.days }

  def to_rsvp_format(date)
    date.strftime('%B %-d, %Y')
  end

  context 'when event is' do
    context 'more than 3m 5d from now' do
      let(:start_date) { Date.today + 3.month + 6.days }

      it('sets deadline 4w from now') { expect(rsvp_by).to eq(to_rsvp_format(4.weeks.from_now)) }
    end

    context '3m 5d from now' do
      let(:start_date) { Date.today + 3.month + 5.days }

      it('sets deadline 21d from now') { expect(rsvp_by).to eq(to_rsvp_format(21.days.from_now)) }
    end

    context 'less than 3m 5d, but more than 2m from now' do
      let(:start_date) { Date.today + 2.month + 10.days }

      it('sets deadline 21d from now') { expect(rsvp_by).to eq(to_rsvp_format(21.days.from_now)) }
    end

    context '2m from now' do
      let(:start_date) { Date.today + 2.month }

      it('sets deadline 10d from now') { expect(rsvp_by).to eq(to_rsvp_format(10.days.from_now)) }
    end

    context 'less than 2m, but more than 10d from now' do
      let(:start_date) { Date.today + 1.month + 15.days }

      it('sets deadline 10d from now') { expect(rsvp_by).to eq(to_rsvp_format(10.days.from_now)) }
    end

    context '10d from now' do
      let(:start_date) { Date.today.beginning_of_week + 10.days }

      it 'sets deadline to Tuesday before event' do
        expect(rsvp_by).to eq(to_rsvp_format(start_date.prev_occurring(:tuesday)))
      end
    end

    context 'less than 10d from now' do
      let(:start_date) { Date.today.beginning_of_week + 9.days }

      it 'sets deadline to Tuesday before event' do
        expect(rsvp_by).to eq(to_rsvp_format(start_date.prev_occurring(:tuesday)))
      end
    end
  end

  context 'when Tuesday before the event is in the past' do
    let(:start_date) { Date.today.beginning_of_week }

    it 'sets deadline to Tuesday before event' do
      expect(rsvp_by).to eq(to_rsvp_format(Date.tomorrow))
    end
  end
end
