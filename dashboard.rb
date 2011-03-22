#!/usr/bin/env ruby
require 'rubygems'
require 'optparse'
require 'logger'

@options = {}
optparse = OptionParser.new do |opts|
  `which nagios-dashboard`; opts.banner = case $?.exitstatus
  when 0
    "Usage: nagios-dashboard [options]"
  else
    "Usage: dashboard.rb [options]"
  end

  @options[:verbose] = false
  opts.on('-v', '--verbose', 'Output debug messages to screen') do
    @options[:verbose] = true
  end

  @options[:datfile] = "/var/cache/nagios3/status.dat"
  opts.on('-d', '--datfile FILE', 'Location of Nagios status.dat FILE (default: /var/cache/nagios3/status.dat)') do |file|
    @options[:datfile] = file
  end

  @options[:port] = 80
  opts.on('-p', '--port PORT', 'Listen on a different PORT (default: 80)') do |port|
    @options[:port] = port
  end

  @options[:logfile] = File.dirname(__FILE__) + '/debug.log'
  opts.on('-l', '--logfile FILE', 'Write log messages to FILE (default: ./debug.log)') do |file|
    @options[:logfile] = file
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
 end
optparse.parse!

@log = Logger.new(@options[:logfile])
@log.debug('starting dashboard ...')

require "bundler/setup"
Bundler.require(:default)

EventMachine.epoll if EventMachine.epoll?
EventMachine.kqueue if EventMachine.kqueue?
EventMachine.run do
  class Dashboard < Sinatra::Base
    set :logging, true
    set :static, true
    set :public, 'public'
    get '/' do
      haml :dashboard
    end
  end

  def log_message(message)
    if @options[:verbose]
      puts message
    end
    EventMachine.defer(proc{@log.debug(message)})
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
      nagios = NagiosAnalyzer::Status.new(@options[:datfile])
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

  EMDirWatcher.watch File.dirname(File.expand_path(@options[:datfile])), :include_only => ['status.dat'] do
    EventMachine.defer(nagios_status, update_clients)
  end

  Dashboard.run!({:port => @options[:port]})
end

@log.debug('stopping dashboard ...')
