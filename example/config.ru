require 'tootsie'

config_path = ENV['TOOTSIE_CONFIG']
config_path ||= '/etc/tootsie/tootsie.conf'

app = Tootsie::Application.new(:logger => ENV["rack.logger"])
app.configure!(config_path)

run Tootsie::WebService
