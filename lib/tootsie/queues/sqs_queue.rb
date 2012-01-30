require 'json'
require 'sqs'
require 'timeout'

module Tootsie
  
  class SqsQueueCouldNotFindQueueError < Exception; end

  # A queue which uses Amazon's Simple Queue Service (SQS).
  class SqsQueue
    
    def initialize(options)
      options.assert_valid_keys(:access_key_id, :secret_access_key, :queue_name, :max_backoff)
      @backoff = Utility::Backoff.new(:max => options[:max_backoff])
      @sqs_service = ::Sqs::Service.new(
        :access_key_id => options[:access_key_id],
        :secret_access_key => options[:secret_access_key])
      @logger = Application.get.logger
      @queue_name = options[:queue_name] || 'tootsie'
      @queue = @sqs_service.queues.find_first(@queue_name)
      unless @queue
        @logger.warn "Queue #{@queue_name} does not exist, creating it"
        @sqs_service.queues.create(@queue_name)
        begin
          timeout(30) do
            while not @queue
              sleep(1)
              @queue = @sqs_service.queues.find_first(@queue_name)
            end
          end
        rescue Timeout::Error
          raise SqsQueueCouldNotFindQueueError
        end
      end
    end
    
    def count
      @queue.attributes['ApproximateNumberOfMessages'].to_i
    end
    
    def push(item)
      retries_left = 5
      begin
        return @queue.create_message(item.to_json)
      rescue Exception => exception
        check_exception(exception)
        if retries_left > 0
          @logger.warn("Writing queue failed with exception (#{exception.message}), will retry")
          retries_left -= 1
          sleep(0.5)
          retry
        else
          @logger.error("Writing queue failed with exception #{exception.class}: #{exception.message}")
          raise exception
        end
      end
    end
    
    def pop(options = {})
      item = nil
      loop do
        @backoff.with do
          begin
            message = @queue.message(5)
          rescue Exception => exception
            check_exception(exception)
            @logger.error("Reading queue failed with exception #{exception.class}: #{exception.message}")
            break unless options[:wait]
            sleep(0.5)
            retry
          end
          if message
            begin
              item = JSON.parse(message.body)
            ensure
              # Always destroy, even if parsing fails
              message.destroy
            end
          end
          if item or not options[:wait]
            true
          else
            false
          end
        end
        break if item
      end
      item
    end

    private

      def check_exception(exception)
        raise exception if exception.is_a?(SystemExit)
        raise exception if exception.is_a?(SignalException) and not exception.is_a?(Timeout::Error)
      end
    
  end
  
end
