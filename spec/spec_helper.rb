ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

require 'rubygems'
begin
  require 'bundler'
rescue LoadError
  # Ignore this
else
  Bundler.setup(:test)
end

# Simplecov must be loaded before everything else
require 'simplecov'
SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'tootsie'

require 'rspec'
require 'rspec/autorun'
require 'rack/test'
require 'webmock/rspec'
require 'pp'

$LOAD_PATH.unshift(File.dirname(__FILE__))

Dir.glob(File.expand_path('../helpers/*.rb', __FILE__)).each do |f|
  require f
end

# Ensure application exists
Tootsie::Application.new

# Enable to get Webmock debug output during tests
if false
  WebMock.after_request do |request_signature, response|
    puts "Request #{request_signature}"
    puts "=> Headers #{response.headers.inspect}"
    puts" => Body    #{response.body.inspect}"
  end
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.include ImageHelper
  config.include FileHelper
  config.before :each do
    WebMock.disable_net_connect!
    WebMock.enable!
    WebMock.reset!
  end
end
