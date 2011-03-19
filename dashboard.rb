#!/usr/bin/env ruby
require 'rubygems'
require 'nagios_analyzer'
require 'optparse'
require 'logger'

@options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: dashboard.rb [options]"

  @options[:verbose] = false
  opts.on('-v', '--verbose', 'Output debug messages to screen') do
    @options[:verbose] = true
  end

  @options[:logfile] = File.dirname(__FILE__) + '/dashboard.log'
  opts.on('-l', '--logfile FILE', 'Write log messages to FILE (default: ./dashboard.log') do |file|
    @options[:logfile] = file
  end

  @options[:datfile] = "/var/cache/nagios3/status.dat"
  opts.on('-d', '--datfile FILE', 'Location of Nagios status.dat FILE (default: /var/cache/nagios3/status.dat)') do |file|
    @options[:datfile] = file
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
 end
optparse.parse!

@log = Logger.new(@options[:logfile])

def log_message(message)
  if @options[:verbose]
    puts message
  end
  @log.debug(message)
end

log_message('Getting current Nagios status ...')

nagios = NagiosAnalyzer::Status.new(@options[:datfile])

log_message('Parsed Nagios status.dat successfully')

puts nagios.items.inspect
