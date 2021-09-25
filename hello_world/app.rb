require 'sinatra'

class HelloWorld
  def self.greeting
    "Hello, World!"
  end
end

get '/' do
  HelloWorld.greeting
end

get '/ping' do
  'pong'
end
