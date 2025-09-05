/* global axios */
import ApiClient from '../ApiClient';

class JitsiAPI extends ApiClient {
  constructor() {
    super('integrations/jitsi', { accountScoped: true });
  }

  createAMeeting(conversationId) {
    return axios.post(`${this.url}/create_a_meeting`, {
      conversation_id: conversationId,
    });
  }
}

export default new JitsiAPI();
