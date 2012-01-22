module Tootsie
    
  class Application
    
    def initialize(options = {})
      @@instance = self
      @logger = Logger.new('/dev/null')
      @configuration = Configuration.new
    end
    
    def configure!(config_path)
      @configuration.load_from_file(config_path)
      case @configuration.log_path
        when 'syslog'
          @logger = SyslogLogger.new('tootsie')
        when String
          @logger = Logger.new(@configuration.log_path)
        else
          @logger = Logger.new($stderr)
      end
      @logger.info "Starting"

      queue_options = @configuration.queue_options ||= {}

      adapter = (queue_options[:adapter] || 'sqs').to_s
      case adapter
        when 'sqs'
          @queue = Tootsie::SqsQueue.new(
            queue_options[:queue],
            @configuration.aws_access_key_id,
            @configuration.aws_secret_access_key)
        when 'amqp'
          @queue = Tootsie::AmqpQueue.new(
            queue_options[:host],
            queue_options[:queue])
        when 'file'
          @queue = Tootsie::FileSystemQueue.new(queue_options[:root])
        else
          raise 'Invalid queue configuration'
      end

      @task_manager = TaskManager.new(@queue)
    end
    
    def s3_service
      abort "AWS access key and secret required" unless
        @configuration.aws_access_key_id and @configuration.aws_secret_access_key
      return @s3_service ||= ::S3::Service.new(
        :access_key_id => @configuration.aws_access_key_id,
        :secret_access_key => @configuration.aws_secret_access_key)
    end
    
    class << self
      def get
        @@instance
      end
    end
        
    attr_reader :configuration
    attr_reader :task_manager
    attr_reader :queue
    attr_reader :logger
    
  end
  
end
