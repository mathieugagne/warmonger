require 'faye/websocket'
require 'thread'
require 'redis'
require 'json'
require 'erb'

module WearHacks2015
  class Warmonger
    KEEPALIVE_TIME = 15 # in seconds
    CHANNEL        = "wearhacks-2015"

    Country = Struct.new(:name, :team)

    def initialize(app)
      @app     = app
      @clients = []
      uri = URI.parse(ENV["REDISCLOUD_URL"])
      @redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
      reset_statistics
      Thread.new do
        redis_sub = Redis.new(host: uri.host, port: uri.port, password: uri.password)
        redis_sub.subscribe(CHANNEL) do |on|
          on.message do |channel, msg|
            @clients.each {|ws| ws.send(msg) }
          end
        end
      end
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = subscribe(env)

        # Return async Rack response
        ws.rack_response

      else
        @app.call(env)
      end
    end

    private

    def subscribe env
      ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME })

      ws.on :open do |event|
        p [:open, ws.object_id]
        @clients << ws
      end

      ws.on :message do |event|
        p [:message, event.data]
        data = sanitize(event.data)
        @redis.publish(CHANNEL, data)
        parsed_object = JSON.parse(data)
        country = Country.new(parsed_object['country'], parsed_object['team'])
        @redis.sadd('countries', country.name)
        @redis.set(country.name, country.team)
      end

      ws.on :close do |event|
        p [:close, ws.object_id, event.code, event.reason]
        @clients.delete(ws)
      end

      ws
    end

    def reset_statistics
      @redis.del('countries')
    end

    def sanitize(message)
      json = JSON.parse(message)
      json.each {|key, value| json[key] = ERB::Util.html_escape(value) }
      JSON.generate(json)
    end

  end
end
