require 'sqs'

module Sqs
  module Parser
    def rexml_document(xml)
      if xml.respond_to? :force_encoding
        if defined?(REXML::Encoding::UTF_8)
          xml.force_encoding(Encoding::UTF_8)
        else
          xml.force_encoding('utf-8')
        end
      end
      Document.new(xml)
    end
  end
end