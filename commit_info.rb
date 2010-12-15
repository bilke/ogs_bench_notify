require 'rubygems'
require 'time'
require 'sequel'
require 'database.rb'
require 'ogs_author_mapping.rb'

Sequel::Model.unrestrict_primary_key

# Create a table if it not exists
$DB.create_table! :commit_infos do
  primary_key     :revision
  Time            :date
  foreign_key     :author_id, :table => :authors
end

class CommitInfo < Sequel::Model(:commit_infos)
  set_primary_key :revision
  many_to_one :author
end

class CommitInfoLoader

  def load_file(filename)
    File.open(filename, 'r') do |file|
      revision = 0
      author = nil
      date = nil

      while line = file.gets
        line.scan(/Revision:\s([0-9]+)/) do |match|
          revision = match[0].to_f
        end
        line.scan(/Last Changed Author:\s([\w]+)/) do |match|
          author_name = match[0]
          author = Author[:svn_user => author_name]
        end
        line.scan(/Last Changed Date:\s([0-9]{4}-[0-9]{2}-[0-9]{2}\s[0-9]{2}:[0-9]{2}:[0-9]{2})/) do |match|
          date = Time.parse(match[0])
        end
      end
      commit_info = CommitInfo.create(:revision => revision, :date => date)
      commit_info.author = author
      commit_info.save
    end
  end

end

CommitInfoLoader.new.load_file('svnInfo.txt')
$DB[:commit_infos].each {|row| p row}