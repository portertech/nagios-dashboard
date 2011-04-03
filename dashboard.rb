#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

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
    :default => File.dirname(__FILE__) + '/debug.log',
    :description => 'Listen on a different PORT'

  option :user,
    :short => '-u USER',
    :long  => '--user USER',
    :description => 'OpsCode plaform USER (required)'

  option :key,
    :short => '-k KEY',
    :long  => '--key KEY',
    :default => '/etc/chef/client.pem',
    :description => 'OpsCode plaform user KEY'

  option :organization,
    :short => '-o ORGANIZATION',
    :long  => '--organization ORGANIZATION',
    :description => 'OpsCode platform ORGANIZATION (required)'

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
    set :static, true
    set :public, 'public'

    Spice.setup do |s|
      s.host = "api.opscode.com"
      s.port = 443
      s.scheme = "https"
      s.url_path = 'organizations/' + OPTIONS.config[:organization]
      s.client_name = OPTIONS.config[:user]
      s.key_file = OPTIONS.config[:key]
    end
    Spice.connect!

    aget '/' do
      EventMachine.defer(proc { haml :dashboard }, proc { |result| body result })
    end

    aget '/node/:hostname' do |hostname|
      content_type 'application/json'
      EventMachine.defer(proc { JSON.parse(Spice::Search.node('hostname:' + hostname))['rows'][0] }, proc { |result| body result.to_json })
    end
  end

  def log_message(message)
    if OPTIONS.config[:verbose]
      puts message
    end
    EventMachine.defer(proc { Log.debug(message) })
  end

  websocket_connections = Array.new
  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 9000) do |websocket|
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
      log_message('parsed nagios status.dat')
      nagios.items.to_json
    rescue => error
      log_message(error)
    end
  end
  
  update_clients = proc do |nagios|
    websocket_connections.each do |websocket|
      websocket.send nagios
    end
    log_message('updated clients')
  end

  EMDirWatcher.watch File.dirname(File.expand_path(OPTIONS.config[:datfile])), :include_only => ['status.dat'], :grace_period => 0.5 do
    EventMachine.defer(nagios_status, update_clients)
  end

  Dashboard.run!({:port => OPTIONS.config[:port]})
end

Log.debug('stopping dashboard ...')
