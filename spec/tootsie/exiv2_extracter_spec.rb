# encoding: utf-8

require 'spec_helper'

if Tootsie::Exiv2MetadataExtractor.available?
  describe Tootsie::Exiv2MetadataExtractor do

    let :extractor do
      Tootsie::Exiv2MetadataExtractor.new
    end

    it 'should read EXIF data' do
      extractor.extract_from_file(test_file_path('iptc.tiff'))
      extractor.metadata['Exif.Image.ImageWidth'][:type].should == 'short'
      extractor.metadata['Exif.Image.ImageWidth'][:value].should == 10
      extractor.metadata['Exif.Image.ImageLength'][:type].should == 'short'
      extractor.metadata['Exif.Image.ImageLength'][:value].should == 10
      extractor.metadata['Exif.Image.ImageDescription'][:type].should == 'ascii'
      extractor.metadata['Exif.Image.ImageDescription'][:value].should == 'Tømmer på vannet ved Krøderen'
    end

    it 'should read IPTC data' do
      extractor.extract_from_file(test_file_path('iptc.tiff'))
      extractor.metadata['Iptc.Application2.City'][:type].should == 'string'
      extractor.metadata['Iptc.Application2.City'][:value].should == 'Krødsherad'
      extractor.metadata['Iptc.Application2.ObjectName'][:type].should == 'string'
      extractor.metadata['Iptc.Application2.ObjectName'][:value].should == 'Parti fra Krødsherad'
    end

    it 'should read XMP data' do
      extractor.extract_from_file(test_file_path('iptc.tiff'))
      extractor.metadata['Xmp.dc.description'][:type].should == 'lang_alt'
      extractor.metadata['Xmp.dc.description'][:value].should == 'lang="x-default" Tømmer på vannet ved Krøderen'
      extractor.metadata['Xmp.tiff.YResolution'][:type].should == 'xmp_text'
      extractor.metadata['Xmp.tiff.YResolution'][:value].should == '300'
    end

  end
else
  warn "'exiv2' tool not available, tests skipped."
end
