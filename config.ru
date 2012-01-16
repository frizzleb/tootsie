require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require

$:.unshift(File.join(File.dirname(__FILE__), "/lib"))
require 'tootsie'

environment = ENV['RACK_ENV'] ||= 'development'
set :environment, environment

logger = Logger.new(File.expand_path("../log/environment.log", __FILE__))

app = Tootsie::Application.new(
  :environment => environment,
  :logger => logger)
app.configure!

if environment == 'development'
  Thread.new do
    Tootsie::Application.get.task_manager.run!
  end
end

run Tootsie::WebService
