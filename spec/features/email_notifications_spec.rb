# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Notifications', type: :feature do
  before do
    login_as user, scope: :user
  end

  let(:user) { create(:user, :admin) }

  describe 'index page' do
    before do
      visit email_notifications_path
    end

    it 'redirects to default location and Invited status' do
      expect(page).to have_current_path(email_notification_path('default', 'Invited'))
    end
  end

  describe 'show email templates' do
    context 'permissions' do
      subject(:path) { email_notification_path('default', 'Invited') }

      it_behaves_like 'allowable only for admins'
    end

    context 'content' do
      let(:eo_invited_email) { create(:email_notification, :eo_invited, body: eo_invited_body) }
      let(:eo_not_yet_invited_email) { create(:email_notification, :eo_not_yet_invited, body: eo_not_yet_invited_body) }
      let(:eo_invited_body) { 'Custom email for EO' }
      let(:eo_not_yet_invited_body) { 'Another text' }

      before do
        eo_invited_email
        eo_not_yet_invited_email

        visit email_notification_path('EO', 'Invited')
      end

      it 'shows right records' do
        expect(page).to have_text(eo_invited_body)
        expect(page).not_to have_text(eo_not_yet_invited_body)
      end

      it 'has a form' do
        within "#edit_email_notification_#{eo_invited_email.id}" do
          select 'Physical', from: 'email_notification[new_event_format]'
          select 'Undecided', from: 'email_notification[new_attendance]'
          select '2 Day Workshop', from: 'email_notification[new_event_type]'
          fill_in 'email_notification_body', with: 'New text'

          click_on 'Update'
        end

        expect(page).to_not have_text('New text')

        visit email_notification_path('EO', 'Undecided')

        expect(page).to have_text 'New text'
      end

      it 'has a delete button' do
        within "#edit_email_notification_#{eo_invited_email.id}" do
          expect { click_on 'Delete' }.to change { EmailNotification.count }.by(-1)
        end
      end

      describe 'new template' do
        before do
          click_on 'Add template'
        end

        it 'create new email' do
          within '#new_email_notification' do
            select 'EO', from: 'email_notification[new_location]'
            select 'Physical', from: 'email_notification[new_event_format]'
            select 'Undecided', from: 'email_notification[new_attendance]'
            select '2 Day Workshop', from: 'email_notification[new_event_type]'
            fill_in 'email_notification_body', with: 'New text'

            expect { click_on 'Create' }.to change { EmailNotification.count }.by(1)
          end
        end
      end
    end
  end

  describe 'default templates' do
    let(:default_email) { create(:email_notification, :default_invited, body: 'New text') }

    before do
      default_email
      visit email_notification_path('default', 'Invited')
    end

    describe 'form' do
      it 'shows record' do
        expect(page).to have_text(default_email.body)
      end

      it 'allows only updating body' do
        within "#edit_email_notification_#{default_email.id}" do
          expect(find('#email_notification_new_location')).to be_disabled
          expect(find('#email_notification_new_attendance')).to be_disabled
          expect(find('#email_notification_body')).not_to be_disabled
          expect(page).not_to have_button('Delete')
          expect(page).to have_button('Update')
        end
      end
    end
  end
end
