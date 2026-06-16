class Api::V1::InboxesController < Api::BaseController
  skip_before_action :authenticate_user!, only: [:bulk_connection_status]
  before_action :verify_n8n_token, only: [:bulk_connection_status]

  def bulk_connection_status
    # Exige que o JSON payload contenha a matriz "statuses"
    statuses = params.require(:statuses) 
    
    ActiveRecord::Base.transaction do
      statuses.each do |item|
        inbox = Inbox.find_by(id: item[:inbox_id])
        next unless inbox # Ignora silenciosamente se o n8n mandar um ID fantasma
        
        new_status = item[:status]
        current_config = inbox.csat_config || {}
        
        # OTIMIZAÇÃO: Só altera o banco e dispara o ActionCable se o status mudou
        if current_config['evolution_status'] != new_status
          inbox.update!(csat_config: current_config.merge('evolution_status' => new_status))
          
          tokens = inbox.account.users.pluck(:pubsub_token).uniq
          ActionCableBroadcastJob.perform_later(
            tokens,
            'inbox.status_updated',
            { 
              id: inbox.id, 
              evolution_status: new_status, 
              account_id: inbox.account_id 
            }
          )
        end
      end
    end

    head :ok
  end

  private

  def verify_n8n_token
    token = request.headers['X-N8N-API-TOKEN']
    unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, ENV['N8N_WEBHOOK_SECRET'].to_s)
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end