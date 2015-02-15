require 'twilio-ruby'

# Get your Account Sid and Auth Token from twilio.com/user/account
account_sid = 'AC307071b7b6333dab0e0d7a00eeb4f939'
auth_token = '1cfd37373215d5386d980c306e1805d9'
@client = Twilio::REST::Client.new account_sid, auth_token

message = @client.account.messages.create(:body => "I love you <3",
  :to => "+19177763154",
  :from => "+12486483034")
puts message.to
