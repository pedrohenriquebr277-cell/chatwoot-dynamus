inbox = Inbox.find_by(name: 'Padaria')
if inbox
  puts "Inbox: #{inbox.name} (ID: #{inbox.id})"
  puts "Channel Type: #{inbox.channel_type}"
  puts "Additional Attributes: #{inbox.channel.additional_attributes.inspect}"
else
  puts "Inbox 'Padaria' not found"
end
