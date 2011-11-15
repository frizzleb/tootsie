# encoding: utf-8

require 'spec_helper'

describe Tootsie::S3Utilities do

  it 'parses URIs with bucket and path' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path")
    out[:bucket].should == 'mybucket'
    out[:key].should == 'some/path'
    out.length.should == 2
  end

  it 'parses URIs and returns indifferent hash' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path")
    out[:bucket].should == out['bucket']
  end

  it 'parses URIs with bucket and path and one key' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path?a=1")
    out[:bucket].should == 'mybucket'
    out[:key].should == 'some/path'
    out[:a].to_s.should == '1'
    out.length.should == 3
  end

  it 'parses URIs with bucket and path and multiple keys' do
    out = Tootsie::S3Utilities.parse_uri("s3:mybucket/some/path?a=1&b=2")
    out[:bucket].should == 'mybucket'
    out[:key].should == 'some/path'
    out[:a].to_s.should == '1'
    out[:b].to_s.should == '2'
    out.length.should == 4
  end

  it 'throws exceptions on non-S3 URIs' do
    lambda { Tootsie::S3Utilities.parse_uri('http://example.com/') }.should raise_error
  end

end
