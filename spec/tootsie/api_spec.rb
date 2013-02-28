require 'spec_helper'

include WebMock::API
include Tootsie::API

describe V1 do

  include Rack::Test::Methods

  def app
    V1
  end

  context "SQS queue" do

    let :application do
      Tootsie::Application.configure!(
        :log_path => '/dev/null',
        :queue => {:queue => "test", :adapter => 'sqs'},
        :aws_access_key_id => "KEY",
        :aws_secret_access_key => "SECRET")
    end

    it "creates queue on initial setup" do
      list_queue_request = stub_request(:post, 'http://queue.amazonaws.com/').
        with(
          :body => hash_including(
            'QueueNamePrefix' => 'test',
            'Action' => 'ListQueues',
            'AWSAccessKeyId' => 'KEY')).
        to_return({
          :status => 200,
          :content_type => 'application/xml',
          :body => %{
            <?xml version="1.0"?>
            <ListQueuesResponse xmlns="http://queue.amazonaws.com/doc/2009-02-01/">
              <ListQueuesResult>
              </ListQueuesResult>
              <ResponseMetadata>
                <RequestId>44000f08-4d52-5e9b-9b43-46a1e117701b</RequestId>
              </ResponseMetadata>
            </ListQueuesResponse>
          }
        }, {
          :status => 200,
          :content_type => 'application/xml',
          :body => %{
            <?xml version="1.0"?>
            <ListQueuesResponse xmlns="http://queue.amazonaws.com/doc/2009-02-01/">
              <ListQueuesResult>
                <QueueUrl>http://queue.amazonaws.com/123123123123/test</QueueUrl>
              </ListQueuesResult>
              <ResponseMetadata>
                <RequestId>44000f08-4d52-5e9b-9b43-46a1e117701b</RequestId>
              </ResponseMetadata>
            </ListQueuesResponse>
          }
        })

      create_queue_request = stub_request(:post, 'http://queue.amazonaws.com/').
        with(
          :body => hash_including(
            'QueueName' => 'test',
            'Action' => 'CreateQueue',
            'AWSAccessKeyId' => 'KEY')).
        to_return(
          :status => 200,
          :content_type => 'application/xml',
          :body => %{
            <?xml version="1.0"?>
            <CreateQueueResponse xmlns="http://queue.amazonaws.com/doc/2009-02-01/">
              <CreateQueueResult>
                <QueueUrl>http://queue.amazonaws.com/947892540417/test</QueueUrl>
              </CreateQueueResult>
              <ResponseMetadata>
                <RequestId>e616a147-f953-59c9-a998-e8ee4b5cc3a4</RequestId>
              </ResponseMetadata>
            </CreateQueueResponse>
          })

      application  # Forces application block to run

      list_queue_request.should have_been_requested.times(2)
      create_queue_request.should have_been_requested
    end

    ["/jobs", "/job"].each do |path|
      describe "POST #{path}" do

        it 'creates job' do
          stub_request(:post, 'http://queue.amazonaws.com/').
            with(
              :body => hash_including(
                'QueueNamePrefix' => 'test',
                'Action' => 'ListQueues',
                'AWSAccessKeyId' => 'KEY')).
            to_return({
              :status => 200,
              :content_type => 'application/xml',
              :body => %{
                <?xml version="1.0"?>
                <ListQueuesResponse xmlns="http://queue.amazonaws.com/doc/2009-02-01/">
                  <ListQueuesResult>
                    <QueueUrl>http://queue.amazonaws.com/123123123123/test</QueueUrl>
                  </ListQueuesResult>
                  <ResponseMetadata>
                    <RequestId>44000f08-4d52-5e9b-9b43-46a1e117701b</RequestId>
                  </ResponseMetadata>
                </ListQueuesResponse>
              }
            })

          application  # Forces application block to run

          stub_request(:post, 'http://queue.amazonaws.com/123123123123/test').
            with(
              :content_type => "application/x-www-form-urlencoded",
              :body => hash_including(
                'Action' => 'SendMessage',
                'AWSAccessKeyId' => 'KEY')).
            to_return(
              :status => 200,
              :body => %{})

          post '/jobs', JSON.dump({
            :type => 'image',
            :notification_url => "http://example.com/transcoder_notification",
            :params => {}
          })
          last_response.status.should == 201
        end

      end
    end

    describe "GET /status" do

      it 'returns a status hash with queue length' do
        stub_request(:post, 'http://queue.amazonaws.com/').
          with(
            :body => hash_including(
              'QueueNamePrefix' => 'test',
              'Action' => 'ListQueues',
              'AWSAccessKeyId' => 'KEY')).
          to_return({
            :status => 200,
            :content_type => 'application/xml',
            :body => %{
              <?xml version="1.0"?>
              <ListQueuesResponse xmlns="http://queue.amazonaws.com/doc/2009-02-01/">
                <ListQueuesResult>
                  <QueueUrl>http://queue.amazonaws.com/123123123123/test</QueueUrl>
                </ListQueuesResult>
                <ResponseMetadata>
                  <RequestId>44000f08-4d52-5e9b-9b43-46a1e117701b</RequestId>
                </ResponseMetadata>
              </ListQueuesResponse>
            }
          })

        application  # Forces application block to run

        stub_request(:post, 'http://queue.amazonaws.com/123123123123/test').
          with(
            :body => hash_including(
              'Action' => 'GetQueueAttributes',
              'AWSAccessKeyId' => 'KEY')).
          to_return(
            :status => 200,
            :content_type => 'application/xml',
            :body => %{
              <?xml version="1.0"?>
                <GetQueueAttributesResponse xmlns="http://queue.amazonaws.com/doc/2009-02-01/">
                  <GetQueueAttributesResult>
                    <Attribute>
                      <Name>QueueArn</Name>
                      <Value>Dustin Hoffman</Value>
                    </Attribute>
                    <Attribute>
                      <Name>ApproximateNumberOfMessages</Name>
                      <Value>42</Value>
                    </Attribute>
                    <Attribute>
                      <Name>ApproximateNumberOfMessagesNotVisible</Name>
                      <Value>0</Value>
                    </Attribute>
                    <Attribute>
                      <Name>CreatedTimestamp</Name>
                      <Value>1318254344</Value>
                    </Attribute>
                    <Attribute>
                      <Name>LastModifiedTimestamp</Name>
                      <Value>1318254344</Value>
                    </Attribute>
                    <Attribute>
                      <Name>VisibilityTimeout</Name>
                      <Value>30</Value>
                    </Attribute>
                    <Attribute>
                      <Name>MaximumMessageSize</Name>
                      <Value>65536</Value>
                    </Attribute>
                    <Attribute>
                      <Name>MessageRetentionPeriod</Name>
                      <Value>345600</Value>
                    </Attribute>
                  </GetQueueAttributesResult>
                  <ResponseMetadata>
                    <RequestId>00f9e1bd-ee78-59fc-824b-a814460091ea</RequestId>
                  </ResponseMetadata>
                </GetQueueAttributesResponse>
              })

        get '/status'
        last_response.status.should == 200
        JSON.parse(last_response.body).should eq({"queue_count" => 42})
      end

    end
  end

end