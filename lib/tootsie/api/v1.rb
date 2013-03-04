require 'sinatra/base'

module Tootsie
  module API
    class V1 < Sinatra::Base

      configure do |config|
        config.set :sessions, false
        config.set :run, false
        config.set :logging, true
        config.set :show_exceptions, false
      end

      register Sinatra::Pebblebed

      not_found do
        halt 404, "Not found"
      end

      post %r{/job(s)?/?} do
        job_data = JSON.parse(request.env["rack.input"].read)
        logger.info "Handling job: #{job_data.inspect}"
        job = Tasks::JobTask.new(job_data)
        unless job.valid?
          halt 400, 'Invalid job specification'
        end
        Application.get.task_manager.schedule(job)
        halt 201, "Job saved."
      end

      get '/status' do
        queue = Application.get.queue
        out = {}
        if (count = queue.count)
          out['queue_count'] = count
        end
        out.to_json
      end

      private

        def logger
          return @logger ||= Application.get.logger
        end

    end
  end
end