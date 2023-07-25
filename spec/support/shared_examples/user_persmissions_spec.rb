# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'allowable only for admins' do
  before do
    login_as user, scope: :user
    visit subject
  end

  context 'when user' do
    let(:user) { create(:user) }

    it { expect(page).not_to have_current_path(subject) }
  end

  context 'when staff' do
    let(:user) { create(:user, :staff) }

    it { expect(page).not_to have_current_path(subject) }
  end

  context 'when admin' do
    let(:user) { create(:user, :admin) }

    it { expect(page).to have_current_path(subject) }
  end

  context 'when super admin' do
    let(:user) { create(:user, :super_admin) }

    it { expect(page).to have_current_path(subject) }
  end
end
