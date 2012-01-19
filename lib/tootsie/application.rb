require 's3'
require 'sqs'

module Tootsie
    
  class Application
    
    def initialize(options = {})
      @@instance = self
      @environment = options[:environment] || :development
      @logger = options[:logger] || Logger.new($stderr)
      @configuration = Configuration.new
    end
    
    def configure!
      @configuration.load_from_file(File.join(Dir.pwd, "config/#{@environment}.yml"))
      @queue = Tootsie::SqsQueue.new(@configuration.sqs_queue_name, sqs_service)
      @task_manager = TaskManager.new(@queue)
    end
    
    def s3_service
      return @s3_service ||= ::S3::Service.new(
        :access_key_id => @configuration.aws_access_key_id,
        :secret_access_key => @configuration.aws_secret_access_key)
    end

    def sqs_service
      return @sqs_service ||= ::Sqs::Service.new(
        :access_key_id => @configuration.aws_access_key_id,
        :secret_access_key => @configuration.aws_secret_access_key)
    end
    
    class << self
      def get
        @@instance
      end
    end
    
    attr_accessor :environment
    
    attr_reader :configuration
    attr_reader :task_manager
    attr_reader :queue
    attr_reader :logger
    
  end
  
end
