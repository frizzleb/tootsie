config_path = ENV['TOOTSIE_CONFIG']
unless config_path
  local_config_path = File.expand_path("../config/tootsie.conf", __FILE__)
  if File.exist?(local_config_path)
    config_path = local_config_path
  else
    config_path = '/etc/tootsie/tootsie.conf'
  end
end

site_config_path = File.expand_path("../config/site.rb", __FILE__)
if File.exist?(site_config_path)
  load(site_config_path)
end

require 'tootsie'
Tootsie::Application.configure!(config_path)

# New API location.
map '/api/tootsie/v1' do
  run Tootsie::API::V1
end
