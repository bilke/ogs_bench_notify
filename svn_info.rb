require 'rubygems'
require 'time'

class SvnInfo

  attr_reader :revision
  attr_reader :date
  attr_reader :author

  def initialize(filename)
    File.open(filename, 'r') do |file|
      while line = file.gets
        line.scan(/Revision:\s([0-9]+)/) do |match|
          @revision = match[0]
        end
        line.scan(/Last Changed Author:\s([\w]+)/) do |match|
          @author = match[0]
        end
        line.scan(/Last Changed Date:\s([0-9]{4}-[0-9]{2}-[0-9]{2}\s[0-9]{2}:[0-9]{2}:[0-9]{2})/) do |match|
          @date = Time.parse(match[0])
        end
      end
    end
  end

end

p SvnInfo.new('svnInfo.txt')