require 'rubygems'
require 'sequel'

#db = Sequel.connect('sqlite://authors.db') #{|db| db[:ogsauthors].delete}


class OgsAuthor #< Sequel::Model
  #set_primary_key :short_name

  attr_reader :name       # Full name
  attr_reader :short_name # Initials
  attr_reader :svn_user   # Subversion user name
  attr_reader :email      # Email address



  def initialize(name, svn_user, email, short_name)
    @name = name
    @svn_user = svn_user
    @email = email
    @short_name = short_name

  end

end

class OgsAuthorLoader

  def load_file(file_name)
    File.open(file_name, 'r') do |file|

      authors = []

      while line = file.gets
        # Ignore commented lines
        if line =~ /^#/
          next
        end

        svn_user = line.scan(/^[\w]+/).to_s
        name = line.scan(/=.+</).to_s
        name = name.gsub(/^=\s/, '').gsub(/\s</, '')
        email = line.scan(/[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+/).to_s
        short_name_match = name.gsub(/Prof.\s|Dr.\s/, '').scan(/[A-Z]|\s[a-z]/)
        short_name = ''
        short_name_match.each { |name_char|
          short_name = short_name + name_char.gsub(/\s/, '').upcase
        }

        #entry = OgsAuthor.create(:name => name, :svn_user => svn_user, :email => email, :short_name => short_name)
        author = OgsAuthor.new(name, svn_user, email, short_name)
        authors.push(author)
        #author.save

      end

      return authors
      
    end
  end

  def create_database(filename)

    # Connect to database in file auhtors.db
    db = Sequel.connect('sqlite://authors.db')

    # Create a table if it not exists
    db.create_table?:items do
      primary_key :id
      String :name
      String :svn_user
      String :email
      unique :short_name
    end

    db_items = db[:items]

    # Load the authors from file
    authors = load_file(filename)

    # Insert authors into database
    authors.each do |author|
      if db_items.filter(:name => author.name.to_s).all.length == 0
        db_items.insert(:name => author.name,
                        :svn_user => author.svn_user,
                        :email => author.email,
                        :short_name => author.short_name)
      end
    end

    return db_items

  end

end


#load = OgsAuthorLoader.new
#db_items = load.create_database('authors.txt')

db = Sequel.connect('sqlite://authors.db')
db_items = db[:items]
print db_items.count

