site_config_path = File.expand_path("../config/site.rb", __FILE__)
if File.exist?(site_config_path)
  load(site_config_path)
end
