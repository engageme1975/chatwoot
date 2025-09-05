require 'rails_helper'

describe Jitsi do
  let(:title) { 'Test Meeting' }
  let(:jitsi_client) { described_class.new }

  describe '#create_a_meeting' do
    it 'returns a meeting hash with id, url, and title' do
      meeting = jitsi_client.create_a_meeting(title)
      expect(meeting[:id]).to be_present
      expect(meeting[:url]).to include('https://meet.jit.si/')
      expect(meeting[:title]).to eq(title)
    end
  end
end
