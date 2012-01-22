require 'json'
require 'sqs'
require 'timeout'

module Tootsie
  
  class SqsQueueCouldNotFindQueueError < Exception; end

  # A queue which uses Amazon's Simple Queue Service (SQS).
  class SqsQueue
    
    def initialize(queue_name, access_key_id, secret_access_key)
      @sqs_service = ::Sqs::Service.new(
        :access_key_id => access_key_id,
        :secret_access_key => secret_access_key)
      @logger = Application.get.logger
      @queue = @sqs_service.queues.find_first(queue_name)
      unless @queue
        @logger.info "Queue #{queue_name} does not exist, creating it"
        @sqs_service.queues.create(queue_name)
        begin
          timeout(30) do
            while not @queue
              sleep(1)
              @queue = @sqs_service.queues.find_first(queue_name)
            end
          end
        rescue Timeout::Error
          raise SqsQueueCouldNotFindQueueError
        end
      end
      @backoff = 0.5
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
          @backoff /= 2.0
          break
        else
          @backoff = [@backoff * 0.2, 2.0].min
        end
        break unless options[:wait]
        sleep(@backoff)
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
