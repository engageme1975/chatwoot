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
    message_content = "Connect AI Meeting Started

Meeting: #{meeting[:title]}
Room: #{meeting[:room_name]}

Join the meeting: #{meeting[:url]}"

    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :outgoing,
      content_type: :text,
      content: message_content,
      sender: agent
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
