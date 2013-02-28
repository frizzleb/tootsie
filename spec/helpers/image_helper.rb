module ImageHelper

  def process_image_versions(test_file_name, version)
    result, content = nil, nil
    Tempfile.open("specs", :encoding => 'binary') do |file|
      file.close

      version[:target_url] = "file:#{file.path}"

      proc = ImageProcessor.new(
        :input_url => test_file_url(test_file_name),
        :versions => [version])
      proc.valid?.should == true
      result = proc.execute!
      result.should have_key(:outputs)
      result[:outputs].length.should == 1
      result[:outputs][0].should have_key(:url)

      content = File.read(file.path)
    end
    [result, content]
  end

  def extract_dimensions(image_data)
    Tempfile.open("specs", :encoding => 'binary') do |file|
      file << image_data
      file.close
      IO.popen("identify -format '%w %h' '#{file.path}'", 'r') do |f|
        f.each_line do |line|
          if line =~ /(\d+) (\d+)/
            width, height = $1.to_i, $2.to_i
            return width, height
          end
        end
      end
    end
  end

end