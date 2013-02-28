# encoding: utf-8

require 'spec_helper'

include Tootsie::Processors

describe ImageProcessor do

  describe 'metadata' do
    it 'returns basic metadata from the original image' do
      result, contents = process_image_version('landscape.jpeg', {})
      result[:width].should eq 360
      result[:height].should eq 240
      result[:depth].should eq 8
    end

    it "returns EXIF and IPTC metadata from the original image that has such metadata" do
      result, contents = process_image_version('iptc_xmp.jpeg', {})
      metadata = result[:metadata]
      metadata.should be_a_kind_of(Hash)

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

  describe 'format conversion' do
    %w(jpeg tiff gif png).each do |format|
      it "converts images to #{format}" do
        result, contents = process_image_version('landscape.jpeg', {:format => format})
        result[:format].should eq format
        extract_dimensions(contents).should eq [360, 240]
      end
    end
  end

  describe 'resizing with scale "down"' do
    let :options do
      {:scale => :down}
    end

    describe 'landscape image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end
    end

    describe 'landscape image, with 270-degree rotation (EXIF orientation 6)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 33]
      end
    end

    describe 'portrait image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end
    end

    describe 'portrait image, with 90-degree rotation (EXIF orientation 6)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [33, 50]
      end
    end
  end

  describe 'resizing with scale "fit"' do
    let :options do
      {:scale => :fit}
    end

    describe 'landscape image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [75, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 50]
      end
    end

    describe 'landscape image, with 270-degree rotation (EXIF orientation 6)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [75, 50]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('landscape_rotated_270.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 50]
      end
    end

    describe 'portrait image' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50}.merge(options))
        extract_dimensions(contents).should eq [50, 75]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait.jpeg',
          {:width => 50, :height => 50, :crop => true}.merge(options))
        extract_dimensions(contents).should eq [50, 50]
      end
    end

    describe 'portrait image, with 90-degree rotation (EXIF orientation 6)' do
      it 'resizes image, preserving aspect ratio' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50, :scale => :fit})
        extract_dimensions(contents).should eq [50, 75]
      end

      it 'resizes image, preserving aspect ratio when cropping to square' do
        result, contents = process_image_version('portrait_rotated_90.jpeg',
          {:width => 50, :height => 50, :scale => :fit, :crop => true})
        extract_dimensions(contents).should eq [50, 50]
      end
    end
  end

end