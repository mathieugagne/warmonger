require 'sinatra/base'

module WearHacks2015

  Country = Struct.new(:name, :team)

  class App < Sinatra::Base
    get "/" do
      erb :"index.html"
    end

    get "/assets/js/map.js" do
      content_type :js
      uri = URI.parse(ENV["REDISCLOUD_URL"])
      @redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)

      @countries = @redis.smembers('countries').collect do |country|
        Country.new(country, @redis.get(country))
      end
      erb :"map.js"
    end

    get "/assets/js/warmonger.js" do
      content_type :js
      @scheme = ENV['RACK_ENV'] == "production" ? "wss://" : "ws://"
      erb :"warmonger.js"
    end

  end
end
