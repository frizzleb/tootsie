require 'iconv'
require 'time'

module Tootsie

  class ImageMetadataExtractor

    def initialize(options = {})
      @logger = options[:logger]
      @metadata = {}
    end

    def extract_from_file(file_name)
      run_exiv2("-pt :file", :file => file_name) do |line|
        parse_exiv2_line(line)
      end
      run_exiv2("-pi :file", :file => file_name) do |line|
        parse_exiv2_line(line)
      end
      run_exiv2("-px :file", :file => file_name) do |line|
        parse_exiv2_line(line)
      end
      @metadata = Hash[*@metadata.entries.map { |key, values|
        [key, values.length > 1 ? values : values.first]
      }.flatten(1)]
      @metadata
    end

    attr_reader :metadata

    private

      def run_exiv2(args, params, &block)
        CommandRunner.new("exiv2 #{args}",
          :output_encoding => 'binary',
          :ignore_exit_code => true
        ).run(params, &block)
      end
    
      def parse_exiv2_line(line)
        if line =~ /^([^\s]+)\s+([^\s]+)\s+\d+  (.*)$/
          key, type, value = $1, $2, $3
          unless value.blank?
            case type
              when 'Short', 'Long'
                value = value.to_i
              when 'Date'
                begin
                  value = Time.parse(value)
                rescue Exception => e
                  if @logger
                    @logger.warn "Invalid time format in EXIF data, ignoring value: #{value.inspect}"
                  end
                  value = nil
                end
              else
                begin
                  Iconv.iconv("utf-8", "utf-8", value)
                rescue Iconv::IllegalSequence, Iconv::InvalidCharacter
                  begin
                    value = Iconv.iconv("utf-8", "iso-8859-1", value)[0]
                  rescue Exception => e
                    if @logger
                      @logger.warn "Invalid encoding in EXIF data, ignoring value: #{value.inspect}"
                    end
                    value = nil
                  end
                else
                  if value.respond_to?(:force_encoding)  # 1.9.
                    value.force_encoding 'utf-8'
                  else
                    value
                  end
                end
            end
            if value
              entry = {:value => value, :type => type.underscore}
              (@metadata[key] ||= []) << entry
            end
          end
        end
      end

  end
end