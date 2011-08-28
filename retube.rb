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
