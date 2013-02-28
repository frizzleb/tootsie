require 'json'

module Tootsie
  module Processors

    class VideoProcessor

      def initialize(params = {})
        @input_url = params[:input_url]
        @thumbnail_options = (params[:thumbnail] || {}).with_indifferent_access
        @versions = [params[:versions] || {}].flatten
        @thread_count = Application.get.configuration.ffmpeg_thread_count
        @logger = Application.get.logger
      end

      def valid?
        return @input_url && !@versions.blank?
      end

      def params
        return {
          :input_url => @input_url,
          :thumbnail => @thumbnail_options,
          :versions => @versions
        }
      end

      def execute!(&block)
        result = {:urls => []}
        input, output, thumbnail_output = Input.new(@input_url), nil, nil
        begin
          input.get!
          begin
            versions.each_with_index do |version_options, version_index|
              version_options = version_options.with_indifferent_access

              if version_index == 0 and @thumbnail_options[:target_url]
                thumbnail_output = Output.new(@thumbnail_options[:target_url])
              else
                thumbnail_output = nil
              end
              begin
                output = Output.new(version_options[:target_url])
                begin
                  if version_options[:strip_metadata]
                    # This actually strips in-place, so no need to swap streams
                    CommandRunner.new("id3v2 --delete-all '#{input.file_name}'").run do |line|
                      if line.present? and line !~ /\AStripping id3 tag in.*stripped\./
                        @logger.warn "ID3 stripping failed, ignoring: #{line}"
                      end
                    end
                  end

                  adapter_options = version_options.dup
                  adapter_options.delete(:target_url)
                  if thumbnail_output
                    adapter_options[:thumbnail] = @thumbnail_options.merge(:filename => thumbnail_output.file_name)
                  else
                    adapter_options.delete(:thumbnail)
                  end

                  adapter = Tootsie::FfmpegAdapter.new(:thread_count => @thread_count)
                  if block
                    adapter.progress = lambda { |seconds, total_seconds|
                      yield(:progress => (seconds + (total_seconds * version_index)) / (total_seconds * versions.length).to_f)
                    }
                  end
                  adapter.transcode(input.file_name, output.file_name, adapter_options)

                  output.content_type = version_options[:content_type] if version_options[:content_type]
                  output.put!

                  result[:urls].push output.result_url
                ensure
                  output.close
                end
                if thumbnail_output
                  thumbnail_output.put!
                  result[:thumbnail_url] = thumbnail_output.result_url
                end
              ensure
                thumbnail_output.close if thumbnail_output
              end
            end
          end
        ensure
          input.close
        end
        result
      end

      attr_accessor :input_url
      attr_accessor :versions
      attr_accessor :thumbnail_options

    end

  end
end
