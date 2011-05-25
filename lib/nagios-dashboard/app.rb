%w{
  mixlib/cli
  mixlib/log
  json
  thin
  eventmachine
  em-websocket
  directory_watcher
  nagios_analyzer
  sinatra/async
  haml
  spice
}.each do |gem|
  require gem
end

class Options
  include Mixlib::CLI
  option :verbose,
    :short => '-v',
    :long  => '--verbose',
    :boolean => true,
    :default => false,
    :description => 'Output debug messages to screen'

  option :datfile,
    :short => '-d FILE',
    :long  => '--datfile FILE',
    :default => '/var/cache/nagios3/status.dat',
    :description => 'Location of Nagios status.dat FILE'

  option :port,
    :short => '-p PORT',
    :long  => '--port PORT',
    :default => 80,
    :description => 'Listen on a different PORT'

  option :logfile,
    :short => '-l FILE',
    :long  => '--logfile FILE',
    :default => '/tmp/nagios-dashboard.log',
    :description => 'Log to a different FILE'

  option :user,
    :short => '-u USER',
    :long  => '--user USER',
    :description => 'Chef USER name'

  option :key,
    :short => '-k KEY',
    :long  => '--key KEY',
    :default => '/etc/chef/client.pem',
    :description => 'Chef user KEY'

  option :help,
    :short => "-h",
    :long => "--help",
    :description => "Show this message",
    :on => :tail,
    :boolean => true,
    :show_options => true,
    :exit => 0
end

class Log
  extend Mixlib::Log
end

OPTIONS = Options.new
OPTIONS.parse_options

Log.init(OPTIONS.config[:logfile])
Log.debug('starting dashboard ...')

EventMachine.epoll if EventMachine.epoll?
EventMachine.kqueue if EventMachine.kqueue?
EventMachine.run do
  class Dashboard < Sinatra::Base
    register Sinatra::Async
    set :root, File.dirname(__FILE__)
    set :static, true
    set :public, Proc.new { File.join(root, "static") }

    Spice.setup do |s|
      s.host = 'api.opscode.com'
      s.port = 443
      s.scheme = "https"
      s.client_name = OPTIONS.config[:user]
      s.key_file = OPTIONS.config[:key]
    end
    Spice.connect!

    aget '/' do
      EventMachine.defer(proc { haml :dashboard }, proc { |result| body result })
    end

    aget '/node/:hostname' do |hostname|
      content_type 'application/json'
      get_chef_attributes = proc do
        split = hostname.split(/_/)
        env = split.first
        hostname = split.last
        JSON.parse(Spice.connection.get("/organizations/sonian-#{env}/search/node", :params => {:q => "hostname:#{hostname}"}))['rows'][0]
      end
      EventMachine.defer(get_chef_attributes, proc { |result| body result.to_json })
    end
  end

  def log_message(message)
    if OPTIONS.config[:verbose]
      puts message
    end
    EventMachine.defer(proc { Log.debug(message) })
  end

  websocket_connections = Array.new
  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8000) do |websocket|
    websocket.onopen do
      websocket_connections.push websocket
      log_message('client connected to websocket')
    end
    websocket.onclose do
      websocket_connections.delete websocket
      log_message('client disconnected from websocket')
    end
  end

  nagios_status = proc do
    begin
      nagios = NagiosAnalyzer::Status.new(OPTIONS.config[:datfile])
      nagios.items.to_json
    rescue => error
      log_message(error)
    end
  end
  
  update_clients = proc do |nagios|
    unless nagios.nil?
      websocket_connections.each do |websocket|
        websocket.send nagios
      end
      log_message('updated clients')
    end
  end

  watcher = DirectoryWatcher.new File.dirname(File.expand_path(OPTIONS.config[:datfile])), :glob => '*.dat', :scanner => :em
  watcher.add_observer do |*args|
    args.each do |event|
      unless websocket_connections.count == 0
        EventMachine.defer(nagios_status, update_clients)
      end
    end
  end
  watcher.start

  Dashboard.run!({:port => OPTIONS.config[:port]})
end

Log.debug('stopping dashboard ...')
