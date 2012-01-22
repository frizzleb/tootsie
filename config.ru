require 'rubygems'
require 'bundler'
Bundler.setup
Bundler.require

$:.unshift(File.join(File.dirname(__FILE__), "/lib"))
require 'tootsie'

config_path = ENV['TOOTSIE_CONFIG']
unless config_path
  abort "You must specify a configuration file with TOOTSIE_CONFIG."
end

app = Tootsie::Application.new(:logger => ENV["rack.logger"])
app.configure!(config_path)

if environment == 'development'
  Thread.new do
    Tootsie::Application.get.task_manager.run!
  end
end

run Tootsie::WebService
