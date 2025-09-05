class Integrations::Jitsi::ProcessorService
  pattr_initialize [:account!, :conversation!]

  def create_a_meeting(agent)
    title = I18n.t('integration_apps.jitsi.meeting_name', agent_name: agent.available_name)
    customer_name = @conversation.contact&.name || 'Customer'
    
    meeting = jitsi_client.create_a_meeting(
      title,
      conversation_id: @conversation.display_id,
      agent_name: agent.available_name,
      customer_name: customer_name
    )
    
    create_a_jitsi_integration_message(meeting, agent).push_event_data
    meeting
  end

  private

  def create_a_jitsi_integration_message(meeting, agent)
    message_content = "🎥 **Connect AI Meeting Started**

**Meeting:** #{meeting[:title]}
**Room:** #{meeting[:room_name]}

👆 **[Click here to join the meeting](#{meeting[:url]})**

💡 *Share this link with the customer to join the video call*"
    
    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content_type: :text,
      content: message_content,
      content_attributes: {
        type: 'jitsi',
        data: {
          meeting_id: meeting[:id],
          meeting_url: meeting[:url],
          meeting_title: meeting[:title],
          room_name: meeting[:room_name]
        }
      },
      sender: agent,
      source_id: Time.now.utc.to_i
    )
  end

  def jitsi_client
    @jitsi_client ||= begin
      hook = @account.hooks.find_by(app_id: 'jitsi')
      settings = hook&.settings || {}
      
      Jitsi.new(
        base_url: settings['base_url'],
        meeting_domain: settings['meeting_domain']
      )
    end
  end
end
