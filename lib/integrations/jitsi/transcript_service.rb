class Integrations::Jitsi::TranscriptService
  pattr_initialize [:conversation!, :transcript_data!]

  def process_transcript
    return unless valid_transcript_data?

    create_transcript_message

    # Optionally, you could also:
    # - Store the transcript as an attachment
    # - Send notifications to agents
    # - Update conversation metadata

    { success: true, message: 'Transcript processed successfully' }
  rescue StandardError => e
    Rails.logger.error "Error processing Jitsi transcript: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def valid_transcript_data?
    transcript_data[:transcript].present? || transcript_data[:transcript_url].present?
  end

  def create_transcript_message
    message = conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content_type: :text,
      content: formatted_transcript_content,
      private: true,
      content_attributes: {
        meeting_transcript: true,
        duration: transcript_data[:duration],
        participants: transcript_data[:participants] || [],
        room_name: transcript_data[:room_name],
        transcript_url: transcript_data[:transcript_url],
        timestamp: Time.current
      },
      sender: nil # System message
    )

    # Trigger webhook and other events
    message.push_event_data if message.persisted?
    message
  end

  def formatted_transcript_content
    # If transcript_url is present, use simple markdown: room_name: [transcript](url)
    if transcript_data[:transcript_url].present?
      room = transcript_data[:room_name] || 'Meeting'
      url = transcript_data[:transcript_url]
      "#{room}: [transcript](#{url})"
    elsif transcript_data[:transcript].present?
      # fallback to showing the transcript text
      "Transcript:\n\n" + format_transcript_text(transcript_data[:transcript])
    else
      'No transcript available.'
    end
  end

  def extract_file_type(url)
    # Extract file extension from URL
    extension = File.extname(URI.parse(url).path).downcase.delete('.')
    case extension
    when 'pdf'
      'PDF'
    when 'txt'
      'Text'
    when 'docx'
      'Word'
    when 'json'
      'JSON'
    else
      'File'
    end
  rescue StandardError
    'File'
  end

  def format_transcript_preview(transcript_text)
    # Show first 150 characters with better formatting
    preview = transcript_text.strip

    # Clean up the preview text
    preview = preview.gsub(/\n+/, ' ')  # Replace multiple newlines with space
    preview = preview.gsub(/\s+/, ' ')  # Normalize whitespace

    if preview.length > 150
      # Try to cut at a sentence or speaker change
      cut_point = preview.rindex(/[.!?]\s/, 150) || preview.rindex(/:\s/, 150) || 147
      preview = preview[0..cut_point] + '...'
    end

    # Add speaker formatting if present
    preview = preview.gsub(/(Agent|Customer|Support|User):/i, "\n\\1:")
    preview.strip
  end

  def format_transcript_text(transcript_text)
    # Format the transcript with better line breaks and speaker identification
    formatted_text = transcript_text.strip

    # Add proper spacing between speakers
    formatted_text = formatted_text.gsub(/\n(Agent|Customer|Support|User):/i, "\n\n\\1:")

    # Ensure it starts clean
    formatted_text = formatted_text.gsub(/\A\n+/, '')

    # Add consistent spacing and improve readability
    formatted_text.gsub(/([.!?])\s*\n/, "\\1\n\n")
  end

  def format_duration(duration_seconds)
    return duration_seconds.to_s unless duration_seconds.is_a?(Numeric)

    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    seconds = duration_seconds % 60

    if hours > 0
      "#{hours}h #{minutes}m #{seconds}s"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end
end
