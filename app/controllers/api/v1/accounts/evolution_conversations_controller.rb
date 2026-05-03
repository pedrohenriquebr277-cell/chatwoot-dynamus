class Api::V1::Accounts::EvolutionConversationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def create
    ActiveRecord::Base.transaction do
      validate_inbox!

      @contact = ContactBuilder.new(
        account: Current.account,
        params: contact_params
      ).perform

      EvolutionApiMessageService.new(
        params[:inbox_id],
        params[:phone_number],
        params[:message]
      ).perform

      # Tenta localizar se a conversa já existe (caso o webhook chegue muito rápido ou já houvesse conversa ativa)
      @conversation = Current.account.conversations.where(contact_id: @contact.id, inbox_id: params[:inbox_id]).last

      render json: {
        success: true,
        contact_id: @contact.id,
        conversation_id: @conversation&.id,
        status: @conversation ? 'sent' : 'sent_waiting_sync'
      }, status: :ok
    end
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def validate_inbox!
    inbox = Current.account.inboxes.find_by(id: params[:inbox_id])
    raise StandardError, 'Inbox inválida ou não pertence a esta conta.' unless inbox
  end

  def contact_params
    {
      name: params[:name].presence,
      phone_number: format_phone_number(params[:phone_number])
    }.compact
  end

  def format_phone_number(phone)
    # Garante que o telefone salvo no Chatwoot tenha o formato E.164 (com +)
    phone_str = phone.to_s.gsub(/[^0-9]/, '')
    phone_str = "+#{phone_str}" unless phone_str.start_with?('+')
    phone_str
  end

  def check_authorization
    # Reutiliza a policy de conversas para garantir que o usuário pode criar conversas
    authorize Conversation, :create?
  end
end
