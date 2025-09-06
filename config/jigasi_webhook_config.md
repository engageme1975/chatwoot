# Jigasi Transcript Webhook Configuration
# Add this to your Jigasi configuration

# Example webhook URL: https://your-chatwoot-domain.com/api/v1/integrations/jitsi/webhooks/transcript

# POST request format expected:
# {
#   "room_name": "conv123-agent-name-abc123",
#   "transcript": "The full meeting transcript text...",
#   "duration": 1800,  # duration in seconds
#   "participants": ["Agent Name", "Customer Name"]
# }

# You'll need to configure Jigasi to:
# 1. Capture transcripts during meetings
# 2. Send HTTP POST requests when meetings end
# 3. Include the room name, transcript, duration, and participants

# Example Jigasi configuration (add to sip-communicator.properties):
# org.jitsi.jigasi.transcription.SAVE_JSON=true
# org.jitsi.jigasi.transcription.WEBHOOK_URL=https://your-chatwoot-domain.com/api/v1/integrations/jitsi/webhooks/transcript

# Security considerations:
# - Add IP whitelist for Jigasi server
# - Use API key authentication
# - Verify webhook signatures

# Example with authentication:
# Add to webhook controller:
# before_action :verify_webhook_auth
# 
# private
# 
# def verify_webhook_auth
#   api_key = request.headers['X-Jigasi-API-Key']
#   unless api_key == ENV['JIGASI_WEBHOOK_API_KEY']
#     render json: { error: 'Unauthorized' }, status: :unauthorized
#   end
# end
