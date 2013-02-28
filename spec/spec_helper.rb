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

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'rspec/autorun'
require 'rack/test'
require 'webmock/rspec'
require 'pp'
require 'tootsie'

Dir.glob(File.expand_path('../helpers/*.rb', __FILE__)).each do |f|
  require f
end

# Ensure application exists
Tootsie::Application.new

RSpec.configure do |config|
  config.mock_with :rspec
  config.include ImageHelper
  config.include FileHelper
end
