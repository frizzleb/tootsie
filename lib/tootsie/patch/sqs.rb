require 'sqs'

module Sqs
  module Parser
    def rexml_document(xml)
      xml.force_encoding('utf-8')
      Document.new(xml)
    end
  end
end