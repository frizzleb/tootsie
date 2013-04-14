module Tootsie

  # A queue which uses the AMQP protocol.
  class AmqpQueue

    def initialize(options = {})
      options.assert_valid_keys(:host_name, :queue_name, :max_backoff)
      @backoff = Utility::Backoff.new(:max => options[:max_backoff])
      @logger = Application.get.logger
      @host_name = options[:host_name] || 'localhost'
      @queue_name = options[:queue_name] || 'tootsie'
    end

    def count
      with_connection do
        if @queue && (status = @queue.status)
          status[:message_count]
        else
          nil
        end
      end
    end

    def push(item)
      data = item.to_json
      with_retry do
        with_connection do
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
            with_connection do
              message = @queue.pop(:ack => true)
            end
          end
          if message
            data = message[:payload]
            data = nil if data == :queue_empty
            if data
              @logger.info "Popped: #{data.inspect}"
              item = JSON.parse(data)
              with_connection do
                @queue.ack(:delivery_tag => message[:delivery_details][:delivery_tag])
              end
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

      def with_connection(&block)
        begin
          connect!
          result = yield
        rescue Bunny::ServerDownError, Bunny::ConnectionError, Bunny::ProtocolError => e
          @logger.error "Error in AMQP server connection (#{e.class}: #{e}), retrying"
          if @connection
            @connection.close rescue nil
            @connection = nil
          end
          sleep(0.5)
          retry
        else
          result
        end
      end

      def with_retry(&block)
        begin
          result = yield
        rescue StandardError => e
          @logger.error("Queue access failed with exception #{e.class} (#{e.message}), will retry")
          sleep(0.5)
          retry
        else
          result
        end
      end

      def connect!
        begin
          @logger.info "Connecting to AMQP server on #{@host_name}"
          unless @connection
            @connection = Bunny.new(:host => @host_name)
            @connection.start
          end

          @exchange = @connection.exchange('')

          @queue = @connection.queue(@queue_name, :durable => true)
        rescue Bunny::ServerDownError
          sleep(0.5)
          retry
        end
      end

  end

end
