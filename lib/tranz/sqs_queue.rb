require 'json'
require 'sqs'
require 'timeout'

module Tranz
  
  class SqsQueueCouldNotFindQueueError < Exception; end

  # A queue which uses Amazon's Simple Queue Service (SQS).
  class SqsQueue
    
    def initialize(queue_name, sqs_service)
      @logger = Application.get.logger
      @sqs_service = sqs_service
      @queue = @sqs_service.queues.find_first(queue_name)
      unless @queue
        @sqs_service.queues.create(queue_name)
        begin
          timeout(5) do
            while not @queue
              sleep(0.5)
              @queue = @sqs_service.queues.find_first(queue_name)
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
    
    def push(job)
      retries_left = 5
      begin
        return @queue.create_message(job.to_json)
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
      job = nil
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
          job = Job.new(JSON.parse(message.body))
          message.destroy
          break
        end
        break unless options[:wait]
        sleep(1.0)
      end
      job
    end

    private

      def check_exception(exception)
        raise exception if exception.is_a?(SystemExit)
        raise exception if exception.is_a?(SignalException) and not exception.is_a?(Timeout::Error)
      end
    
  end
  
end
