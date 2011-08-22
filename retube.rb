#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'redis'

require 'pp'

class RetubeOptions
  def self.parse(args)
    options = OpenStruct.new
    options.direction = :in
    options.name = nil

    opts = OptionParser.new do |opts|
      opts.banner = 'Usage: retube.rb [options]'

      opts.separator ""
      opts.separator "Specific options:"

      opts.on('-i', '--in TUBE', 'Receive data from TUBE') do |tube|
        options.name = tube
        options.direction = :in
      end
        
      opts.on('-o', '--out TUBE', 'Send data to TUBE') do |tube|
        options.name = tube
        options.direction = :out
      end

      opts.separator ""
      opts.separator "Common options:"
      
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    opts.parse!(args)
    options
  end
end

class Tube
  attr_reader :name, :direction
  OUTOFBAND = '.oob'

  def initialize(name, direction, persist=false)
    @name, @direction = name, direction
    @oob = self.class.outofband(name)
    @redis = Redis.connect
  end

  def self.outofband(channel)
    channel + OUTOFBAND
  end

  def transact(&block)
    @redis.publish @oob, 'begin'
    yield
    @redis.publish @oob, 'end'
  end
  
  def go
    if @direction == :in then
      self.in 
    else
      transact {self.out}
    end
  end

  def in
    @redis.subscribe(@name, @oob) do |on|
      on.message do |channel, message|
        if channel == @oob then
          @redis.unsubscribe if !@persist and message == 'end'
        else
          puts message
        end
      end
    end
  end

  def out
    ARGF.each_line do |line|
      @redis.publish @name, line
    end
  end
end
      
trap(:INT) { exit }

options = RetubeOptions.parse(ARGV)
tube = Tube.new(options.name, options.direction).go
pp options
