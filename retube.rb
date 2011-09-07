#!/usr/bin/env ruby

# Copyright 2011 Brian Hetro
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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

    if options.name.nil?
      puts 'ERROR: Missing tube type. Specify --in or --out.'
      puts
      puts opts
      exit
    end

    options
  end
end

class Tube
  attr_reader :config

  OUTOFBAND = '.oob'

  def self.outofband(channel)
    channel + OUTOFBAND
  end

  def initialize(name, direction, persist=false)
    @config = OpenStruct.new
    @config.name = name
    @config.direction = direction
    @config.persist = persist
    @config.redis = Redis.connect
    @config.oob = self.class.outofband(name)

    @tube = (direction == :in ? In : Out).new(@config)
  end

  def go
    if @config.direction == :in then
      @tube.receive
    else
      @tube.send ARGF
    end
  end

  class In
    def initialize(config)
      @tube = config
    end

    def receive
      @tube.redis.subscribe(@tube.name, @tube.oob) do |on|
        on.message do |channel, message|
          if channel == @tube.oob then
            oob message
          else
            handle message
          end
        end
      end
    end

    def oob(message)
      @tube.redis.unsubscribe if !@tube.persist and message == 'end'
    end

    def handle(data)
      puts data
    end
  end

  class Out
    def initialize(config)
      @tube = config
    end

    def oob(message)
      @tube.redis.publish @tube.oob, message
    end

    def transact(&block)
      oob 'begin'
      yield
      oob 'end'
    end

    def send(data)
      data = *data
      transact {
        data.each do |line|
          @tube.redis.publish @tube.name, line
        end
      }
    end
  end
end

trap(:INT) { exit }

options = RetubeOptions.parse(ARGV)
tube = Tube.new(options.name, options.direction).go
