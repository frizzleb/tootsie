module Tootsie
  
  class Configuration
    
    def initialize
      @ffmpeg_thread_count = 1
      @worker_count = 4
      @sqs_queue_name = 'tootsie'
    end
    
    def load_from_file(file_name)
      config = (YAML.load(File.read(file_name)) || {}).with_indifferent_access
      [:aws_access_key_id, :aws_secret_access_key, :ffmpeg_thread_count,
        :sqs_queue_name, :worker_count, :pid_path, :log_path].each do |key|
        if config.include?(key)
          value = config[key]
          value = $1.to_i if value =~ /\A\s*(\d+)\s*\z/
          instance_variable_set("@#{key}", value)
        end
      end
    end
    
    attr_accessor :aws_access_key_id
    attr_accessor :aws_secret_access_key
    attr_accessor :ffmpeg_thread_count
    attr_accessor :sqs_queue_name
    attr_accessor :pid_path
    attr_accessor :log_path
    attr_accessor :worker_count
    
  end
  
end
