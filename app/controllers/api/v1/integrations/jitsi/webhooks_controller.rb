class Api::V1::Integrations::Jitsi::WebhooksController < ApplicationController
  skip_before_action :set_current_user
  before_action :verify_webhook_auth

  def transcript_webhook
    # Verify the webhook source (implement security as needed)
    # You might want to verify API key, IP whitelist, or signature

    transcript_data = {
      room_name: params[:room_name],
      transcript: params[:transcript],
      transcript_url: params[:transcript_url],
      duration: params[:duration],
      participants: params[:participants] || []
    }

    # Find the conversation by room name
    conversation = find_conversation_by_room_name(transcript_data[:room_name])

    if conversation
      service = Integrations::Jitsi::TranscriptService.new(
        conversation: conversation,
        transcript_data: transcript_data
      )
      result = service.process_transcript

      if result[:success]
        render json: { success: true, message: result[:message] }, status: :ok
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "Jitsi transcript webhook error: #{e.message}"
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  private

  def verify_webhook_auth
    api_key = request.headers['X-Jigasi-API-Key']
    expected_key = ENV.fetch('JIGASI_WEBHOOK_API_KEY', nil)

    if expected_key.present? && api_key != expected_key
      render json: { error: 'Unauthorized' }, status: :unauthorized
      return false
    end

    # Also check IP whitelist if configured
    allowed_ips = ENV['JIGASI_ALLOWED_IPS']&.split(',')&.map(&:strip)
    if allowed_ips.present? && !allowed_ips.include?(request.remote_ip)
      render json: { error: 'Forbidden' }, status: :forbidden
      return false
    end

    true
  end

  def find_conversation_by_room_name(room_name)
    # Extract conversation ID from room name
    # Room names are typically: "conv-123-agent-name-randomhex" or "meeting-domain-conv123-agent-name-randomhex"
    return unless room_name =~ /conv-?(\d+)/

    conversation_id = ::Regexp.last_match(1)
    Conversation.find_by(display_id: conversation_id)
  end
end
