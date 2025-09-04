class Integrations::Jitsi::ProcessorService
  pattr_initialize [:account!, :conversation!]

  def create_a_meeting(agent)
    title = I18n.t('integration_apps.jitsi.meeting_name', agent_name: agent.available_name)
    meeting = jitsi_client.create_a_meeting(title)
    create_a_jitsi_integration_message(meeting, title, agent).push_event_data
    meeting
  end

  private

  def create_a_jitsi_integration_message(meeting, title, agent)
    message_content = "#{title}

Click here to join: #{meeting[:url]}"
    
    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content_type: :text,
      content: message_content,
      sender: agent,
      source_id: Time.now.utc.to_i
    )
  end

  def jitsi_client
    @jitsi_client ||= Jitsi.new
  end
end
