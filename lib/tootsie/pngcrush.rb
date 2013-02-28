module Tootsie
  module Pngcrush

    @available = nil

    def self.available?
      if @available.nil?
        @available = IO.popen("pngcrush -h >/dev/null 2>&1", 'r') { |f| f.read } &&
          $?.exitstatus == 0
      end
      @available
    end

    def self.process!(file_name)
      Tempfile.open('tootsie') do |file|
        # TODO: Make less sloppy
        file.write(File.read(file_name))
        file.close
        CommandRunner.new('pngcrush :input_file :output_file').run(
          :input_file => file.path, :output_file => file_name)
      end
    end

  end
end