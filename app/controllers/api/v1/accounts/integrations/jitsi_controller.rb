class Api::V1::Accounts::Integrations::JitsiController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  before_action :set_agent
  before_action :authorize_request

  def create_a_meeting
    processor = Integrations::Jitsi::ProcessorService.new(account: current_account, conversation: @conversation)
    meeting_data = processor.create_a_meeting(@agent)
    render json: { success: true, meeting: meeting_data }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def authorize_request
    authorize @conversation.inbox, :show?
  end

  def set_conversation
    @conversation = current_account.conversations.find_by!(display_id: params[:conversation_id])
  end

  def set_agent
    @agent = current_user
  end
end
