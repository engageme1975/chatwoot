# Jitsi Transcript Integration for Chatwoot

This document describes the Jitsi transcript integration that allows automatic delivery of meeting transcripts from Jigasi (Jitsi Gateway to SIP) to Chatwoot conversations.

## Overview

The integration provides a webhook endpoint that receives transcript data from Jigasi and automatically adds the transcript to the corresponding Chatwoot conversation as a private agent note. This enables support agents to review meeting transcripts for context without exposing them to customers.

## Features

- **Automatic Transcript Delivery**: Transcripts are automatically delivered to conversations when meetings end
- **Private Agent Notes**: Transcripts appear as private messages visible only to agents
- **Markdown Support**: Transcript content supports markdown formatting for better readability
- **Flexible Input**: Supports both transcript URLs and raw transcript text
- **Conversation Matching**: Automatically matches transcripts to conversations based on room names
- **Security**: API key authentication and optional IP whitelisting

## Architecture

```
Jitsi Meeting → Jigasi → Transcript Webhook → Chatwoot Conversation
```

1. **Jitsi Meeting**: Users participate in a video meeting
2. **Jigasi**: Records and transcribes the meeting
3. **Transcript Webhook**: Jigasi sends transcript data to Chatwoot
4. **Chatwoot Conversation**: Transcript appears as a private agent note

## Setup

### 1. Environment Configuration

Add the following environment variables to your Chatwoot `.env` file:

```bash
# Required: API key for webhook authentication
JIGASI_WEBHOOK_API_KEY=your-secret-api-key-here

# Optional: IP whitelist for additional security (comma-separated)
JIGASI_ALLOWED_IPS=192.168.1.100,10.0.0.50
```

### 2. Restart Chatwoot Services

After adding environment variables, restart Chatwoot to load the configuration:

```bash
sudo systemctl restart chatwoot.target
```

### 3. Configure Jigasi

Configure your Jigasi instance to send webhooks to:

```
POST https://your-chatwoot-domain.com/api/v1/integrations/jitsi/webhooks/transcript
```

## API Reference

### Webhook Endpoint

**URL**: `POST /api/v1/integrations/jitsi/webhooks/transcript`

**Headers**:
```
Content-Type: application/json
X-Jigasi-API-Key: your-secret-api-key-here
```

**Request Body**:
```json
{
  "room_name": "conv12345-agent-support-abc123",
  "transcript_url": "https://storage.example.com/transcripts/meeting.txt",
  "transcript": "Alternative raw transcript text",
  "duration": 1800,
  "participants": ["Agent Sarah", "Customer Mike"]
}
```

**Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `room_name` | string | Yes | Meeting room name containing conversation ID (e.g., "conv12345-...") |
| `transcript_url` | string | No* | URL to the transcript file |
| `transcript` | string | No* | Raw transcript text content |
| `duration` | number | No | Meeting duration in seconds |
| `participants` | array | No | List of meeting participants |

*Note: Either `transcript_url` or `transcript` must be provided.

**Response**:
```json
{
  "success": true,
  "message": "Transcript processed successfully"
}
```

**Error Response**:
```json
{
  "error": "Conversation not found"
}
```

### Room Name Format

The room name must contain the conversation ID in one of these formats:
- `conv-12345-agent-name-randomhex`
- `conv12345-agent-name-randomhex`
- `meeting-domain-conv123-agent-name-randomhex`

The system extracts the conversation ID using regex pattern: `/conv-?(\d+)/`

## Message Format

### With Transcript URL
When `transcript_url` is provided, the message appears as:
```
room_name: [transcript](https://storage.example.com/transcripts/meeting.txt)
```

### With Raw Transcript
When `transcript` text is provided, the message appears as:
```
Transcript:

**Agent Sarah:** Hello! How can I help you today?

**Customer Mike:** I need help with my account. Can you check my *recent orders*?

**Agent Sarah:** Of course! Let me look that up for you.
```

## Security

### Authentication
- **API Key**: Required `X-Jigasi-API-Key` header
- **Environment Variable**: `JIGASI_WEBHOOK_API_KEY` must be set

### IP Whitelisting (Optional)
- **Environment Variable**: `JIGASI_ALLOWED_IPS` (comma-separated list)
- **Example**: `JIGASI_ALLOWED_IPS=192.168.1.100,10.0.0.50`

### Message Privacy
- All transcript messages are created as **private notes**
- Only agents can see transcript messages
- Customers never see transcripts in their conversation view

## Testing

### Test Webhook with cURL

```bash
curl -X POST https://your-chatwoot-domain.com/api/v1/integrations/jitsi/webhooks/transcript \
  -H "Content-Type: application/json" \
  -H "X-Jigasi-API-Key: your-secret-api-key-here" \
  -d '{
    "room_name": "conv12345-agent-support-test",
    "transcript_url": "https://example.com/transcripts/test-meeting.txt"
  }'
```

### Expected Response
```json
{"success":true,"message":"Transcript processed successfully"}
```

## Troubleshooting

### Common Issues

**1. "Unauthorized" Error**
- Check that `JIGASI_WEBHOOK_API_KEY` is set in environment
- Verify the `X-Jigasi-API-Key` header matches the environment variable
- Restart Chatwoot after changing environment variables

**2. "Conversation not found" Error**
- Verify room name contains conversation ID in correct format
- Check that conversation with the extracted ID exists
- Ensure conversation ID is numeric

**3. "Forbidden" Error**
- Check IP whitelisting configuration
- Verify request is coming from allowed IP addresses

### Debug Mode

Check Chatwoot logs for detailed error information:
```bash
tail -f log/production.log | grep "Jitsi transcript"
```

## File Structure

```
app/controllers/api/v1/integrations/jitsi/
└── webhooks_controller.rb          # Webhook endpoint controller

lib/integrations/jitsi/
└── transcript_service.rb           # Transcript processing service

config/routes.rb                    # Webhook route configuration
```

## Implementation Details

### Controller (`webhooks_controller.rb`)
- Handles webhook authentication
- Validates request parameters
- Finds conversation by room name
- Delegates processing to service

### Service (`transcript_service.rb`)
- Processes transcript data
- Creates private messages
- Formats markdown content
- Handles both URL and text input

### Route Configuration
```ruby
namespace :api do
  namespace :v1 do
    namespace :integrations do
      namespace :jitsi do
        post 'webhooks/transcript', to: 'webhooks#transcript_webhook'
      end
    end
  end
end
```

## Changelog

### Version 1.0.0 (September 2025)
- Initial implementation
- Webhook endpoint for transcript delivery
- Support for transcript URLs and raw text
- Private message creation
- Markdown formatting support
- API key authentication
- IP whitelisting support
- Conversation matching by room name

## Support

For issues or questions about this integration:
1. Check the troubleshooting section above
2. Review Chatwoot logs for error details
3. Verify environment configuration
4. Test with the provided cURL examples

## License

This integration is part of Chatwoot and follows the same licensing terms.
