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
EventMachine.run do
  class Dashboard < Sinatra::Base
    register Sinatra::Async
    set :static, true
    set :public, 'public'

    aget '/' do
      EventMachine.defer(proc { haml :dashboard }, proc { |result| body result })
    end

    aget '/node/:hostname' do |hostname|
      content_type 'application/json'
      get_chef_attributes = proc do
        split = hostname.split(/_/)
        env = split.first
        hostname = split.last
        Spice.setup do |s|
          s.host = 'api.opscode.com'
          s.port = 443
          s.scheme = 'https'
          s.url_path = 'organizations/sonian-' + env
          s.client_name = OPTIONS.config[:user]
          s.key_file = OPTIONS.config[:key]
        end
        Spice.connect!
        JSON.parse(Spice::Search.node('hostname:' + hostname))['rows'][0]
      end
      EventMachine.defer(get_chef_attributes, proc { |result| body result.to_json })
    end

    apost '/nagios/hosts' do
      receive_json = proc do
        nodes = JSON.parse(request.body.read)
        env = ""
        nodes.each do |node|
          env += "define host {\n"
          env += "  use server\n"
          env += "  address #{node['automatic']['ipaddress']}\n"
          env += "  host_name #{node['override']['app_environment']}_#{node['automatic']['hostname']}\n"
          if node['automatic'].include? 'roles'
            env += "  hostgroups #{node['automatic']['roles'].to_a.join(',')}\n"
            if node['automatic']['roles'].include? 'spot'
              env += "  notifications_enabled 0\n"
            end
          end
          env += "}\n\n"
        end
        node = nodes.first
        nagios_config = "/etc/nagios3/conf.d/#{node['override']['app_environment']}_hosts.cfg"
        old_env = ""
        if File.exists?(nagios_config)
          File.open(nagios_config, "r") do |file|
            file.each_line do |line|
              old_env += line
            end
          end
        end
        unless env == old_env
          File.open(nagios_config, "w") do |file|
            file.write(env)
          end
          `/etc/init.d/nagios3 restart`
        end
        "Successfully updated the Nagios host list for '#{node['override']['app_environment']}'"
      end
      EventMachine.defer(receive_json, proc { |result| body result })
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
      nagios.items.to_json
    rescue => error
      log_message(error)
    end
  end
  
  update_clients = proc do |nagios|
    websocket_connections.each do |websocket|
      websocket.send nagios
    end
    log_message('updated clients') if websocket_connections.count > 0
  end

  EMDirWatcher.watch File.dirname(File.expand_path(OPTIONS.config[:datfile])), :include_only => ['status.dat'], :grace_period => 0.5 do
    EventMachine.defer(nagios_status, update_clients)
  end

  Dashboard.run!({:port => OPTIONS.config[:port]})
end

Log.debug('stopping dashboard ...')
