require 'httpclient'
require 'uri'
require 'benchmark'

module Tootsie

  class TaskManager

    def initialize(queue)
      @queue = queue
      @logger = Application.get.logger
    end

    def schedule(task)
      type = task.class.name.gsub(/^(?:[^:]+::)*(.*?)Task$/, '\1').underscore
      data = task.attributes
      @logger.info("Scheduling task #{type.inspect}: #{data.inspect}")
      @queue.push({:task => type, :data => data})
    end

    def run!
      @logger.info "Ready to process tasks"
      loop do
        Application.get.handle_exceptions do
          task = @queue.pop(:wait => true)
          if task
            task = task.with_indifferent_access
            type, data = task[:task], task[:data]
            @logger.info("Processing task #{type.inspect}: #{data.inspect}")
            begin
              task_class = Tasks.const_get("#{type.camelcase}Task")
            rescue NameError
              @logger.error("Invalid task encountered on queue: #{task.inspect}")
            else
              task = task_class.new(data)
              task.execute!
            end
          end
        end
      end
      @logger.info "Task manager done"
    end

  end

end
