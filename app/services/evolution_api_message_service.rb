class EvolutionApiMessageService
  include HTTParty

  def initialize(inbox_id, phone_number, message)
    @inbox_id = inbox_id
    @phone_number = phone_number
    @message = message
    @base_url = ENV.fetch('EVOLUTION_API_URL', nil)
    @api_key = ENV.fetch('EVOLUTION_API_KEY', nil)
  end

  def perform
    validate_credentials!
    
    instance_name = resolve_instance_name
    Rails.logger.info "[EvolutionService] Using instance: #{instance_name}"
    raise StandardError, 'A Caixa de Entrada (Inbox) não tem uma instância Evolution configurada.' if instance_name.blank?

    payload = {
      number: format_number_for_evolution(@phone_number),
      text: @message
    }
    Rails.logger.info "[EvolutionService] Sending to instance #{instance_name} | TextLen: #{@message&.length || 0}"

    response = self.class.post(
      "#{@base_url}/message/sendText/#{instance_name}",
      headers: {
        'Content-Type' => 'application/json',
        'apikey' => @api_key
      },
      body: payload.to_json
    )

    unless response.success?
      Rails.logger.error("Evolution API Error: #{response.body}")
      raise StandardError, "Falha ao enviar mensagem pela Evolution API: #{response.code}"
    end

    response.parsed_response
  end

  private

  def validate_credentials!
    raise StandardError, 'URL da Evolution API não está configurada no servidor.' if @base_url.blank?
    raise StandardError, 'API Key da Evolution não está configurada no servidor.' if @api_key.blank?
  end

  def resolve_instance_name
    inbox = Inbox.find_by(id: @inbox_id)
    return nil unless inbox

    # 1. Tentar buscar nas configurações do canal
    if inbox.channel.respond_to?(:additional_attributes) && inbox.channel.additional_attributes.present?
      instance = inbox.channel.additional_attributes['evolution_instance'] || 
                 inbox.channel.additional_attributes['instance']
      return instance if instance.present?
    end

    # 2. Tentar buscar pelo mapa em variável de ambiente
    map_env = ENV.fetch('EVOLUTION_INBOX_INSTANCE_MAP', '{}')
    begin
      mapping = JSON.parse(map_env)
      return mapping[@inbox_id.to_s] if mapping[@inbox_id.to_s].present?
    rescue JSON::ParserError
      Rails.logger.warn("EVOLUTION_INBOX_INSTANCE_MAP is not a valid JSON")
    end

    nil
  end

  def format_number_for_evolution(phone)
    # Remove qualquer sinal de +, espaços, parênteses ou traços
    phone.to_s.gsub(/[^0-9]/, '')
  end
end
