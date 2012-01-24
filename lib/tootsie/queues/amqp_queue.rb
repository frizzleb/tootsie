module Tootsie

  # A queue which uses the AMQP protocol.
  class AmqpQueue
    
    def initialize(options = {})
      options.assert_valid_keys(:host_name, :queue_name, :max_backoff)
      @backoff = Utility::Backoff.new(:max => options[:max_backoff])
      @logger = Application.get.logger
      @host_name = options[:host_name] || 'localhost'
      @queue_name = options[:queue_name] || 'tootsie'
      connect!
    end
    
    def count
      nil
    end
    
    def push(item)
      data = item.to_json
      with_retry do
        with_reconnect do
          @exchange.publish(data, :persistent => true, :key => @queue_name)
        end
      end
    end
    
    def pop(options = {})
      item = nil
      loop do
        @backoff.with do
          message = nil
          with_retry do
            with_reconnect do
              message = @queue.pop(:ack => true)
            end
          end
          if message
            data = message[:payload]
            data = nil if data == :queue_empty
            if data
              @logger.info "Popped: #{data.inspect}"
              item = JSON.parse(data)
              with_reconnect do
                @queue.ack(:delivery_tag => message[:delivery_details][:delivery_tag])
              end
              true
            end
          end
          break unless options[:wait]
        end
        break if item
      end
      item
    end

    private

      def with_reconnect(&block)
        begin
          result = yield
        rescue Bunny::ServerDownError
          @logger.error "Error connecting to AMQP server, retrying"
          connect!
          retry
        else
          result
        end
      end

      def with_retry(&block)
        begin
          result = yield
        rescue Exception => exception
          check_exception(exception)
          @logger.error("Queue access failed with exception #{exception.class} (#{exception.message}), will retry")
          sleep(0.5)
          retry
        else
          result
        end
      end

      def connect!
        begin
          @logger.info "Connecting to AMQP server on #{@host_name}"

          @connection = Bunny.new(:host => @host_name)
          @connection.start
          
          @exchange = @connection.exchange('')

          @queue = @connection.queue(@queue_name, :durable => true)
        rescue Bunny::ServerDownError
          sleep(0.5)
          retry
        end
      end

      def check_exception(exception)
        raise exception if exception.is_a?(SystemExit)
        raise exception if exception.is_a?(SignalException) and not exception.is_a?(Timeout::Error)
      end
    
  end
  
end
