import ApiClient from './ApiClient';

class EvolutionConversationsAPI extends ApiClient {
  constructor() {
    super('evolution_conversations');
  }

  create({ inbox_id, name, phone_number, message }) {
    return this.axios.post(this.url, {
      inbox_id,
      name,
      phone_number,
      message,
    });
  }
}

export default new EvolutionConversationsAPI();
