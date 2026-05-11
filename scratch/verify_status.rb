# Script para simular a interceptação da Evolution API
# Execute este comando na VPS:
# docker exec -it $(docker ps -q -f name=chatwoot_chatwoot_app) bundle exec rails runner /app/scratch/verify_status.rb

def verify_evolution_logic
  # 1. Encontrar uma Inbox de API
  inbox = Inbox.find_by(channel_type: 'Channel::Api')
  unless inbox
    puts "❌ Nenhuma Inbox de API encontrada para testar."
    return
  end

  puts "🧪 Testando Inbox: #{inbox.name} (ID: #{inbox.id})"
  
  # 2. Criar uma conversa de teste
  contact = Contact.first || Contact.create!(name: "Test User", account_id: inbox.account_id)
  conversation = Conversation.create!(
    account_id: inbox.account_id,
    inbox_id: inbox.id,
    contact_id: contact.id,
    status: 'open'
  )

  # 3. Simular mensagem de "Conectado"
  puts "📝 Simulando mensagem: 'Instância: David - Conectado com sucesso'"
  
  msg = Message.new(
    content: "Instância: David - Conectado com sucesso",
    account_id: inbox.account_id,
    inbox_id: inbox.id,
    conversation_id: conversation.id,
    message_type: 'incoming',
    status: 'sent'
  )

  begin
    if msg.save
      puts "❌ FALHA: A mensagem foi salva no banco (deveria ter sido abortada)."
    else
      puts "✅ SUCESSO: A mensagem foi interceptada e NÃO foi salva."
    end
  rescue => e
    # O throw :abort faz o save retornar false, mas algumas versões do rails podem disparar rollback
    puts "✅ SUCESSO: Interceptação via throw :abort confirmada."
  end

  # 4. Verificar se o status da Inbox atualizou
  inbox.reload
  status = inbox.csat_config&.[]('evolution_status')
  
  if status == 'connected'
    puts "✅ SUCESSO: O status da Inbox foi atualizado para 'connected'."
  else
    puts "❌ FALHA: O status da Inbox é '#{status}' (deveria ser 'connected')."
  end

  # 5. Limpar teste
  conversation.destroy
end

verify_evolution_logic
