$:.unshift(File.join(File.dirname(__FILE__), "/lib"))
require 'tootsie'

config_path = ENV['TOOTSIE_CONFIG']
config_path ||= '/etc/tootsie/tootsie.conf'

app = Tootsie::Application.new(:logger => ENV["rack.logger"])
app.configure!(config_path)

if ENV['RACK_ENV'] == 'development'
  Thread.new do
    Tootsie::Application.get.task_manager.run!
  end
end

run Tootsie::WebService
