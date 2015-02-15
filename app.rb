require 'twilio-ruby'
require 'google/api_client'
require 'logger'
require 'json'
require 'sinatra'
require 'sinatra/activerecord'
require './config/environments' #database configuration
require './models/user'
require 'rufus/scheduler'

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
  session[:phone] = params[:phone]
  if params["my-checkbox".to_sym] == 'on'
    session[:sex] = 'boy'
  else
    session[:sex] = 'girl'
  end
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
  #[result.status, {'Content-Type' => 'application/json'}, result.data.to_json]
  json = JSON.parse(result.data.to_json)
  json.to_s
  #"#{json[:items][0][:summary]} : #{json[:items][0][:creator][:displayName]} : #{json[:items][0][:start][:dateTime]}"
  output = ""
  json["items"].each do |j|

    u = User.where(name: j["creator"]["displayName"])
    if u.empty?
      u = User.new
    else
      u = u.first
    end
    u.sex = session[:sex]
    u.name = j["creator"]["displayName"]
    u.email = j["creator"]["email"]
    u.phone = session[:phone]
    u.save

    e = Event.where(summary: j["summary"])

    if e.empty?
      e = Event.new
    else
      e = e.first
    end

    e.summary = j["summary"]
    e.time = j["start"]["dateTime"]
    e.user_id = u.id
    e.save
      #output += "#{e.id} : #{u.name} : #{u.email} : #{u.phone} : #{e.summary} : #{e.time} "
  end
  #output
  erb :index2
end

get '/' do
  erb :index
end

get '/unsubscribe' do
  erb :index3
end

get '/killeverything' do
  u = User.where(phone: params[:phone])
  unless u.empty?
    u = u.first
    Event.where(user_id: u.id).delete_all
    u.delete
  end
  erb :index
end


scheduler = Rufus::Scheduler.new
if ARGV[0] == "peon"
  #scheduler.cron '0 06 * * 0-6' do
  # every day of the week at 22:00 (10pm)
  scheduler.every '1m' do
    account_sid = 'AC307071b7b6333dab0e0d7a00eeb4f939'
    auth_token = '1cfd37373215d5386d980c306e1805d9'

    @client = Twilio::REST::Client.new account_sid, auth_token

    Event.where(time: 6.hours.from_now..7.hours.from_now).each do |event|
      user = User.find(event.user_id)
      puts "#{user.name} : #{user.phone}"
      if user.sex == 'boy'
        message = @client.account.messages.create(:body => "Hey #{[:boo, :gorgeous, :captain, :sweetie, :honey, :baby, :sweetheart, :cutie, :handsome, :darling].sample}, have fun at your #{event.summary} today!",
        :to => "+1#{user.phone}",
        :from => "+12486483034")
        puts message.to
      else
        message = @client.account.messages.create(:body => "Hey #{[:beautiful, :gorgeous, :sweetie, :honey, :baby, :sweetheart, :cutie, :sunshine, :cookie, :sugarpie, :darling, :lovely, :angel].sample}, have fun at your #{event.summary} today!",
        :to => "+1#{user.phone}",
        :from => "+12486483034")
        puts message.to
      end
    end
  end
end
