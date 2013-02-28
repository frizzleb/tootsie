# encoding: utf-8

require 'spec_helper'

include Tootsie::Processors

describe ImageProcessor do

  describe 'metadata' do
    it 'returns basic metadata from the original image' do
      result, contents = process_image_versions('landscape.jpeg',
        {:width => 50, :height => 50})
      result[:width].should == 360
      result[:height].should == 240
      result[:depth].should == 8
    end

    %w(
      Exif.Image.ImageDescription
      Exif.Image.Orientation
      Exif.Image.XResolution
      Exif.Image.YResolution
      Exif.Image.ResolutionUnit
      Exif.Image.Software
      Exif.Image.DateTime
      Exif.Image.Artist
      Exif.Image.Copyright
      Exif.Image.ExifTag
      Exif.Photo.ColorSpace
      Exif.Photo.PixelXDimension
      Exif.Photo.PixelYDimension
      Exif.Thumbnail.Compression
      Exif.Thumbnail.XResolution
      Exif.Thumbnail.YResolution
      Exif.Thumbnail.ResolutionUnit

      Iptc.Application2.RecordVersion
      Iptc.Application2.Caption
      Iptc.Application2.Writer
      Iptc.Application2.Headline
      Iptc.Application2.SpecialInstructions
      Iptc.Application2.Byline
      Iptc.Application2.BylineTitle
      Iptc.Application2.Credit
      Iptc.Application2.Source
      Iptc.Application2.ObjectName
      Iptc.Application2.DateCreated
      Iptc.Application2.City
      Iptc.Application2.ProvinceState
      Iptc.Application2.CountryName
      Iptc.Application2.TransmissionReference
      Iptc.Application2.Keywords
      Iptc.Application2.Copyright
    ).each do |key|
      it "returns metadata property '#{key}' from the original image" do
        result, contents = process_image_versions('iptc_xmp.jpeg',
          {:width => 50, :height => 50})
        metadata = result[:metadata]
        metadata.should be_a_kind_of(Hash)
        metadata.should have_key(key)
        if metadata[key].is_a?(Array)
          metadata[key].each do |value|
            value.should be_a_kind_of(Hash)
            value.should have_key(:value)
            value.should have_key(:type)
            %w(
              short rational long ascii string xmp_text xmp_bag xmp_seq date
            ).should include(value[:type])
          end
        else
          metadata[key].should be_a_kind_of(Hash)
          metadata[key].should have_key(:value)
          metadata[key].should have_key(:type)
          %w(
            short rational long ascii string xmp_text xmp_bag xmp_seq date
          ).should include(metadata[key][:type])
        end
      end
    end
  end

  describe 'resizing' do
    it 'resizes image, preserving aspect ratio (landscape)' do
      result, contents = process_image_versions('landscape.jpeg',
        {:width => 50, :height => 50})

      result[:outputs].length.should == 1

      contents.length.should > 0
      width, height = extract_dimensions(contents)
      width.should == 50
      height.should == 33
    end

    it 'resizes image, preserving aspect ratio (portrait)' do
      result, contents = process_image_versions('portrait.jpeg',
        {:width => 50, :height => 50})

      result[:outputs].length.should == 1

      contents.length.should > 0
      width, height = extract_dimensions(contents)
      width.should == 33
      height.should == 50
    end
  end

  describe 'format conversion' do
    it 'converts images to GIF' do
      result, contents = process_image_versions('landscape.jpeg',
        {:format => 'gif'})

      result[:outputs].length.should == 1

      contents.length.should > 0
      width, height = extract_dimensions(contents)
      width.should == 360
      height.should == 240
    end
  end

end