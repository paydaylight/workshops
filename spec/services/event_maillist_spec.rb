# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

# Event Maillist handler
describe 'EventMaillist' do
  let(:params) do
    {
      to: ['event_code@example.com'],
      from: 'Webby Webmaster <webmaster@example.net>',
      subject: 'Testing email processing',
      text: 'A Test Message.',
      Date: "Tue, 25 Sep 2018 16:17:17 -0600",
      headers: { 'Message-Id' => '1234-safas-98y6@uni.edu' }
    }
  end

  subject { Griddler::Email.new(params) }

  let(:event) { create(:event, max_virtual: 5) }
  let(:status) { 'Undecided' }
  let(:subgroup) { nil }
  let(:list_params) do
    {
      email: subject,
      event: event,
      group: status,
      subgroup: subgroup,
      destination: params[:to].first,
    }
  end

  before do
    2.times do
      create(:membership, event: event, attendance: status, role: 'Participant')
    end
  end

  it '.initialize' do
    expect(EventMaillist.new(subject, list_params).class).to eq(EventMaillist)
  end

  context '.send_message' do
    let(:mailer) { double('MaillistMailer') }
    let(:maillist) { EventMaillist.new(subject, list_params) }

    before do
      @domain = GetSetting.site_setting('app_url').gsub(/^.+\/\//, '')
      params[:to] = ["#{event.code}@#{@domain}"]

      allow(MaillistMailer).to receive(:workshop_maillist).and_return(mailer)
    end

    it 'sends one email per participant of specified attendance status' do
      num_participants = event.attendance(status).count
      expect(num_participants).to be > 0
      expect(mailer).to receive(:deliver_now).exactly(num_participants).times

      maillist.send_message

      expect(MaillistMailer).to have_received(:workshop_maillist).exactly(num_participants).times
    end

    it 'excludes Backup Participants from Not Yet Invited group' do
      expect(event.memberships.count).to eq(2)
      event.memberships.each do |member|
        member.attendance = 'Not Yet Invited'
        member.save
      end
      member = event.memberships.last
      member.role = 'Backup Participant'
      member.save

      params[:to] = ["#{event.code}-not_yet_invited@#{@domain}"]
      list_params[:group] = 'Not Yet Invited'

      allow(MaillistMailer).to receive(:workshop_maillist).and_return(mailer)
      expect(mailer).to receive(:deliver_now).exactly(1).times

      maillist.send_message

      expect(MaillistMailer).to have_received(:workshop_maillist)
                                  .exactly(1).times
    end

    it 'sends to organizers if "orgs" group is specified' do
      member = event.memberships.first
      member.role = 'Organizer'
      member.save
      expect(event.organizers.count).to eq(1)
      list_params[:group] = 'orgs'

      allow(MaillistMailer).to receive(:workshop_organizers).and_return(mailer)
      expect(mailer).to receive(:deliver_now).exactly(1).times

      maillist.send_message

      expect(MaillistMailer).to have_received(:workshop_organizers)
                                  .exactly(1).times
    end

    it '"all" group sends to Confirmed, Invited, and Undecided members' do
      event2 = create(:event_with_members)
      member_count = event2.attendance('Confirmed').count +
        event2.attendance('Invited').count +
        event2.attendance('Undecided').count

      list_params[:event] = event2
      list_params[:group] = 'all'

      allow(MaillistMailer).to receive(:workshop_maillist).and_return(mailer)
      expect(mailer).to receive(:deliver_now).exactly(member_count).times

      maillist.send_message

      expect(MaillistMailer).to have_received(:workshop_maillist)
                                  .exactly(member_count).times
    end

    it '"speakers" sends to scheduled speakers' do
      event2 = create(:event_with_members)
      speaker_count = 3
      hour = 8
      event2.attendance('Confirmed').sample(speaker_count).each do |speaker|
        hour += 1
        start_time = (event2.start_date + 1.days).in_time_zone(event2.time_zone).change({ hour: hour, min:0})
        end_time = start_time + 45.minutes
        create(:lecture, person: speaker.person, event: event2,
                         start_time: start_time, end_time: end_time)
      end

      list_params[:event] = event2
      list_params[:group] = 'speakers'

      allow(MaillistMailer).to receive(:workshop_maillist).and_return(mailer)
      expect(mailer).to receive(:deliver_now).exactly(speaker_count).times

      maillist.send_message
      expect(MaillistMailer).to have_received(:workshop_maillist).exactly(speaker_count).times
    end

    describe '"in_person" subgroup' do
      let(:subgroup) { 'in_person' }

      before do
        event.memberships.delete_all
        create(:membership, role: 'Contact Organizer', event: event, attendance: status)
        create(:membership, role: 'Organizer', event: event, attendance: status)
        create(:membership, role: 'Participant', event: event, attendance: status)
        # Not targets
        create(:membership, role: 'Organizer', event: event, attendance: 'Undecided')
        create(:membership, role: 'Observer', event: event, attendance: status)
        create(:membership, role: 'Participant', event: event, attendance: 'Declined')

        allow(MaillistMailer).to receive(:workshop_maillist).and_return(mailer)
        expect(mailer).to receive(:deliver_now).exactly(3).times

        maillist.send_message
      end

      context 'when Confirmed group' do
        let(:status) { 'Confirmed' }

        it 'sends to Contact Organizer, Organizer, Participant' do
          expect(MaillistMailer).to have_received(:workshop_maillist).exactly(3).times
        end
      end

      describe 'when Invited group' do
        let(:status) { 'Invited' }

        it 'sends to Contact Organizer, Organizer, Participant' do
          expect(MaillistMailer).to have_received(:workshop_maillist).exactly(3).times
        end
      end

      describe 'when Not Yet Invited group' do
        let(:status) { 'Not Yet Invited' }

        it 'sends to Contact Organizer, Organizer, Participant' do
          expect(MaillistMailer).to have_received(:workshop_maillist).exactly(3).times
        end
      end
    end

    describe '"online" subgroup' do
      let(:subgroup) { 'online' }

      before do
        event.memberships.delete_all
        create(:membership, role: 'Virtual Organizer', event: event, attendance: status)
        create(:membership, role: 'Virtual Participant', event: event, attendance: status)
        # Not targets
        create(:membership, role: 'Organizer', event: event, attendance: 'Undecided')
        create(:membership, role: 'Observer', event: event, attendance: status)
        create(:membership, role: 'Participant', event: event, attendance: 'Declined')

        allow(MaillistMailer).to receive(:workshop_maillist).and_return(mailer)
        expect(mailer).to receive(:deliver_now).exactly(2).times

        maillist.send_message
      end

      context 'when Confirmed group' do
        let(:status) { 'Confirmed' }

        it 'sends to Virtual Organizer, Virtual Participant' do
          expect(MaillistMailer).to have_received(:workshop_maillist).exactly(2).times
        end
      end

      describe 'when Invited group' do
        let(:status) { 'Invited' }

        it 'sends to Virtual Organizer, Virtual Participant' do
          expect(MaillistMailer).to have_received(:workshop_maillist).exactly(2).times
        end
      end

      describe 'when Not Yet Invited group' do
        let(:status) { 'Not Yet Invited' }

        it 'sends to Virtual Organizer, Virtual Participant' do
          expect(MaillistMailer).to have_received(:workshop_maillist).exactly(2).times
        end
      end
    end

    it "records the email's Message-Id in the database when message is sent" do
      num_participants = event.attendance(status).count
      expect(mailer).to receive(:deliver_now).exactly(num_participants).times
      maillist.send_message

      message_id = params[:headers]['Message-Id']
      message_record = Sentmail.find_by_message_id(message_id)

      expect(message_record).not_to be_nil
      expect(message_record.sender).to eq(params[:from])
      expect(message_record.recipient).to eq(params[:to].first)
      updated_subject = "[#{event.code}] #{params[:subject]}"
      expect(message_record.subject).to eq(updated_subject)
    end
  end
end
