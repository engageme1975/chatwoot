class Jitsi
  BASE_URL = 'https://meet.jit.si'.freeze

  def create_a_meeting(title)
    room_name = "chatwoot-#{SecureRandom.hex(8)}"
    {
      id: room_name,
      url: "#{BASE_URL}/#{room_name}",
      title: title
    }
  end

  # Jitsi does not require adding participants via API
end
