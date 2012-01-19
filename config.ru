require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require

$:.unshift(File.join(File.dirname(__FILE__), "/lib"))
require 'tootsie'

environment = ENV['RACK_ENV'] ||= 'development'

app = Tootsie::Application.new(
  :environment => environment,
  :logger => ENV["rack.logger"])
app.configure!

if environment == 'development'
  Thread.new do
    Tootsie::Application.get.task_manager.run!
  end
end

run Tootsie::WebService
