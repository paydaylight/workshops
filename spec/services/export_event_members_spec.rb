# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportEventMembers do
  subject(:service_call) { described_class.new(event_ids: event_ids, options: params).call }

  let(:event) do
    create(:event, code: '22w999',
                   start_date: '2023-01-20',
                   end_date: '2023-01-25',
                   event_format: 'Physical',
                   event_type: '5 Day Workshop',
                   location: 'EO',
                   confirmed_count: 1,
                   subjects: 'Some subjects')
  end

  let(:event_ids) { [event.id] }

  def create_membership(person, role:, attendance:)
    create(:membership, :stub_for_report, event: event, role: role, attendance: attendance, person: person)
  end

  before do
    people = []

    4.times do |i|
      people << create(:person, :stub_for_report, email: "person-#{i + 1}@example.com")
    end

    create_membership(people[0], role: 'Organizer', attendance: 'Confirmed')
    create_membership(people[1], role: 'Participant', attendance: 'Invited')
    create_membership(people[2], role: 'Participant', attendance: 'Not Yet Invited')
    create_membership(people[3], role: 'Observer', attendance: 'Declined')
  end

  context 'when some fields selected' do
    let(:params) do
      {
        event_code: '1',
        attendance: '1',
        name: '1',
        email: '1',
        department: '1',
        year_of_phd: '1',
        event_subjects: '0',
        confirmed_count: '0'
      }
    end

    let(:csv) { File.open(Rails.root.join('spec', 'files', 'reports', 'some_fields_selected.csv')).read }

    it 'uses only those fields' do
      expect(service_call.report).to eq(csv)
    end
  end

  context 'when all fields' do
    let(:params) do
      {
        event_code: '1',
        event_format: '1',
        event_type: '1',
        confirmed_count: '1',
        event_subjects: '1',
        event_location: '1',
        attendance: '1',
        role: '1',
        name: '1',
        email: '1',
        arriving_on: '1',
        departing_on: '1',
        has_guests: '1',
        number_of_guests: '1',
        billing: '1',
        special_info: '1',
        affiliation: '1',
        department: '1',
        academic_status: '1',
        year_of_phd: '1',
        organizer_notes: '1',
        gender: '1',
        research_areas: '1',
        title: '1',
        nserc_grant: '1'
      }
    end

    let(:csv) { File.open(Rails.root.join('spec', 'files', 'reports', 'all_fields.csv')).read }

    it 'reports on all fields' do
      expect(service_call.report).to eq(csv)
    end
  end

  context 'when no field selected' do
    let(:params) { {} }

    it { expect(service_call.valid?).to be_falsey }
    it { expect(service_call.report).to be_nil }
  end

  context 'when non existent field is selected' do
    let(:params) do
      {
        event_code: '1',
        attendance: '1',
        name: '1',
        email: '1',
        department: '1',
        year_of_phd: '1',
        i_dont_exist: '1'
      }
    end

    let(:csv) { File.open(Rails.root.join('spec', 'files', 'reports', 'some_fields_selected.csv')).read }

    it 'removes extra fields' do
      expect(service_call.report).to eq(csv)
    end
  end

  context 'when some attendance fields are selected' do
    let(:params) do
      {
        event_code: '1',
        attendance: '1',
        confirmed: '1',
        declined: '1',
        name: '1',
        email: '1'
      }
    end

    let(:csv) { File.open(Rails.root.join('spec', 'files', 'reports', 'some_attendance_fields_selected.csv')).read }

    it 'filters by attendance' do
      expect(service_call.report).to eq(csv)
    end
  end
end
