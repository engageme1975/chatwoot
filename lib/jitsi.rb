class Jitsi
  DEFAULT_BASE_URL = 'https://meet.jit.si'.freeze

  def initialize(base_url: nil, meeting_domain: nil)
    @base_url = base_url&.chomp('/') || DEFAULT_BASE_URL
    @meeting_domain = meeting_domain
  end

  def create_a_meeting(title, conversation_id: nil, agent_name: nil, customer_name: nil)
    room_name = generate_room_name(conversation_id, agent_name)
    meeting_title = generate_meeting_title(title, conversation_id, agent_name, customer_name)
    
    {
      id: room_name,
      url: "#{@base_url}/#{room_name}",
      title: meeting_title,
      room_name: room_name
    }
  end

  private

  def generate_room_name(conversation_id, agent_name)
    parts = []
    parts << @meeting_domain if @meeting_domain.present?
    parts << "conv#{conversation_id}" if conversation_id
    parts << agent_name&.parameterize if agent_name
    parts << SecureRandom.hex(4)
    
    parts.join('-').downcase
  end

  def generate_meeting_title(title, conversation_id, agent_name, customer_name)
    details = []
    details << "Agent: #{agent_name}" if agent_name
    details << "Customer: #{customer_name}" if customer_name
    details << "Conversation ##{conversation_id}" if conversation_id
    details << "Started: #{Time.current.strftime('%Y-%m-%d %H:%M UTC')}"
    
    if details.any?
      "#{title} - #{details.join(' | ')}"
    else
      title
    end
  end

  # Connect AI (Jitsi) does not require adding participants via API
end
