#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'json'
require 'redis'

Country = Struct.new(:name, :team)

uri = URI.parse(ENV["REDISCLOUD_URL"])
@redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
@countries = @redis.smembers('countries').collect do |country|
  Country.new(country, @redis.get(country))
end

@teams = @countries.collect(&:team).uniq

@teams.each do |team|
  puts "#{team}: #{@countries.count{|c| c.team == team}} countries"
end
