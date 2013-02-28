module Tootsie
  module Processors

    class ImageProcessor

      def initialize(params = {})
        @input_url = params[:input_url]
        @versions = [params[:versions] || {}].flatten
        @logger = Application.get.logger
        @extractor = ImageMetadataExtractor.new(:logger => @logger)
      end

      def valid?
        return @input_url && !@versions.blank?
      end

      def params
        return {
          :input_url => @input_url,
          :versions => @versions
        }
      end

      def execute!(&block)
        result = {:outputs => []}
        input, output = Input.new(@input_url), nil
        begin
          input.get!
          begin
            versions.each_with_index do |version_options, version_index|
              version_options = version_options.with_indifferent_access
              @logger.info("Handling version: #{version_options.inspect}")

              output = Output.new(version_options[:target_url])
              begin
                result[:metadata] ||= @extractor.extract_from_file(input.file_name)

                original_depth = nil
                original_width = nil
                original_height = nil
                original_type = nil
                original_format = nil
                original_orientation = nil
                CommandRunner.new("identify -format '%z %w %h %m %[EXIF:Orientation] %r' :file").
                  run(:file => input.file_name) do |line|
                  if line =~ /(\d+) (\d+) (\d+) ([^\s]+) (\d+)? (.+)/
                    original_depth, original_width, original_height = $~[1, 3].map(&:to_i)
                    original_format = $4.downcase
                    original_orientation = $5.try(:to_i)
                    original_type = $6
                  end
                end
                unless original_width and original_height
                  raise "Unable to determine dimensions of input image"
                end

                if (output_format = version_options[:format])
                  # Sanitize format so we can use it in file name
                  output_format = output_format.to_s
                  output_format.gsub!(/[^\w]/, '')
                end
                output_format ||= original_format
                result[:format] = output_format

                # Correct for EXIF orientation
                if [5, 6, 7, 8].include?(original_orientation)
                  original_width, original_height = original_height, original_width
                end

                original_aspect = original_height / original_width.to_f

                result[:width] = original_width
                result[:height] = original_height
                result[:depth] = original_depth

                medium = version_options[:medium]
                medium &&= medium.to_sym

                new_width, new_height =
                  version_options[:width].try(:to_i),
                  version_options[:height].try(:to_i)
                if new_width
                  new_height ||= (new_width * original_aspect).ceil
                elsif new_height
                  new_width ||= (new_height / original_aspect).ceil
                else
                  new_width, new_height = original_width, original_height
                end

                scale = (version_options[:scale] || 'down').to_sym
                case scale
                  when :down
                    if new_width > original_width
                      scale_width = original_width
                      scale_height = (original_width * original_aspect).ceil
                    elsif new_height > original_height
                      scale_height = original_height
                      scale_width = (original_height / original_aspect).ceil
                    end
                  when :fit
                    if (new_width * original_aspect).ceil < new_height
                      scale_height = new_height
                      scale_width = (new_height / original_aspect).ceil
                    elsif (new_height / original_aspect).ceil < new_width
                      scale_width = new_width
                      scale_height = (new_width * original_aspect).ceil
                    end
                end
                scale_width ||= new_width
                scale_height ||= new_height

                convert_command = "convert"
                convert_options = {
                  :input_file => input.file_name,
                  :output_file => "'#{output_format}:#{output.file_name}'"
                }

                if original_format != version_options[:format] and %(gif tiff).include?(original_format)
                  # Remove additional frames (animation, TIFF thumbnails) not
                  # supported by the output format
                  convert_command << ' -delete "1-999" -flatten -scene 1'
                end

                if scale != :none
                  convert_command << " -resize :resize"
                  convert_options[:resize] = "#{scale_width}x#{scale_height}"
                end
                if version_options[:crop]
                  convert_command << " -gravity center -crop :crop"
                  convert_command << " +repage"  # This fixes some animations
                  convert_options[:crop] = "#{new_width}x#{new_height}+0+0"
                end
                if version_options[:strip_metadata]
                  convert_command << " +profile :remove_profiles -set comment ''"
                  convert_options[:remove_profiles] = "8bim,iptc,xmp,exif"
                end

                convert_command << " -quality #{((version_options[:quality] || 1.0) * 100).ceil}%"

                if original_format =~ /^(jpeg|tiff)$/i
                  # Work around a problem with ImageMagick being too clever and "optimizing"
                  # the bit depth of RGB images that contain a single grayscale channel.
                  # Coincidentally, this avoids ImageMagick rewriting the ICC data and
                  # corrupting it in the process.
                  if original_type =~ /(?:Gray|RGB)(Matte)?$/
                    convert_command << " -type TrueColor#{$1}"
                  end
                end

                # Fix CMYK images
                if medium == :web and original_type =~ /CMYK/
                  convert_command << " -colorspace rgb"
                end

                # Auto-orient images when web or we're stripping EXIF
                if medium == :web or version_options[:strip_metadata]
                  convert_command << " -auto-orient"
                end

                if original_format == 'gif' and output_format == 'gif'
                  # Work around ImageMagick problem that screws up animations unless the
                  # animation frames are "coalesced" first.
                  convert_command = "convert -coalesce :input_file - | #{convert_command} - :output_file"
                else
                  convert_command << " :input_file :output_file"
                end

                CommandRunner.new(convert_command).run(convert_options)

                if version_options[:format] == 'png'
                  Tempfile.open('tootsie') do |file|
                    # TODO: Make less sloppy
                    file.write(File.read(output.file_name))
                    file.close
                    CommandRunner.new('pngcrush :input_file :output_file').run(
                      :input_file => file.path, :output_file => output.file_name)
                  end
                end

                output.content_type = version_options[:content_type] if version_options[:content_type]
                output.content_type ||= case version_options[:format]
                  when 'jpeg' then 'image/jpeg'
                  when 'png' then 'image/png'
                  when 'gif' then 'image/gif'
                end
                output.put!
                result[:outputs] << {:url => output.result_url}
              ensure
                output.close
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

    end

  end
end
