require 'rubygems'
require 'bundler'
Bundler.require(:default)
require 'google/api_client'
require 'logger'

# Get your Account Sid and Auth Token from twilio.com/user/account
#account_sid = 'AC307071b7b6333dab0e0d7a00eeb4f939'
#auth_token = '1cfd37373215d5386d980c306e1805d9'
#@client = Twilio::REST::Client.new account_sid, auth_token

#message = @client.account.messages.create(:body => "I love you <3", :to => "+9177763154", :from => "+12486483034", :media_url => "http://www.example.com/hearts.png")
#puts message.to
#calendar stuff

enable :sessions

def logger; settings.logger end

def api_client; settings.api_client; end

def calendar_api; settings.calendar; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
    auth = api_client.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

configure do
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG

  client = Google::APIClient.new
  client.authorization.client_id = '819350760249-mb0kjvrb3ilk9c8q7o2oojkph3nnhl2f.apps.googleusercontent.com'
  client.authorization.client_secret = 'kB7dHa3xROZot_9d_HtD621j'
  client.authorization.scope = 'https://www.googleapis.com/auth/calendar'

  calendar = client.discovered_api('calendar', 'v3')

  set :logger, logger
  set :api_client, client
  set :calendar, calendar
end

#before do
  # Ensure user has authorized the app
#  unless user_credentials.access_token || request.path_info =~ /^\/oauth2/
#    redirect to('/oauth2authorize')
#  end
#end

after do
  # Serialize the access/refresh token to the session
  session[:access_token] = user_credentials.access_token
  session[:refresh_token] = user_credentials.refresh_token
  session[:expires_in] = user_credentials.expires_in
  session[:issued_at] = user_credentials.issued_at
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/results')
end

get '/results' do
  # Fetch list of events on the user's default calandar
  result = api_client.execute(:api_method => settings.calendar.events.list,
                              :parameters => {'calendarId' => 'primary'},
                              :authorization => user_credentials)
  [result.status, {'Content-Type' => 'application/json'}, result.data.to_json]
end

get '/' do
  erb :index
end

get '/test' do
  erb :index
end

post '/test' do
  @x = params[:data]
  erb :index2
end

get '/test2' do
  erb :index2
end
