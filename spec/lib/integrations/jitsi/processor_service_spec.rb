require 'rails_helper'

describe Integrations::Jitsi::ProcessorService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent) { create(:user, account: account) }

  subject { described_class.new(account: account, conversation: conversation) }

  describe '#create_a_meeting' do
    it 'creates a Jitsi meeting and posts a message' do
      expect {
        subject.create_a_meeting(agent)
      }.to change { conversation.messages.count }.by(1)

      message = conversation.messages.last
      expect(message.content_type).to eq('integrations')
      expect(message.content_attributes[:type]).to eq('jitsi')
      expect(message.content_attributes[:data][:meeting_url]).to include('https://meet.jit.si/')
    end
  end
end
