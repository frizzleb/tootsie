load File.expand_path("../boot.rb", __FILE__)

require 'tootsie'
config_path = ENV['TOOTSIE_CONFIG']
unless config_path
  local_config_path = File.expand_path("../config/tootsie.conf", __FILE__)
  if File.exist?(local_config_path)
    config_path = local_config_path
  else
    config_path = '/etc/tootsie/tootsie.conf'
  end
end
Tootsie::Application.configure!(config_path)

# New API location.
map '/api/tootsie/v1' do
  run Tootsie::API::V1
end

# Old API location, for backwards compatibility.
map '/' do
  run Tootsie::API::V1
end
