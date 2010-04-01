require 'rubygems'
require 'xml/libxml'
require 'sequel'
require 'date'

DB = Sequel.connect("sqlite://test.db")

def create_table()
  if !DB.table_exists?(:programs)
     DB.create_table :programs do
       primary_key :id
       varchar :channel_id, :size => 20
       varchar :category_id, :size => 20
       varchar :title, :size => 512
       varchar :description, :size => 512
       datetime :start
       datetime :end
     end
  end
end

def parseDateTime(str)
  DateTime.strptime(str, "%Y%m%d%H%M%S")
end

def import(filename)
  programs = DB[:programs]
  
  doc = XML::Document.file(filename)
  
  doc.root.find('//tv/channel').each do |e|
    p e.attributes[:id]
    #p e.find_first('display-name').content
  end

  doc.root.find('//tv/programme').each do |e|
    programs << {
      :channel_id => e.attributes[:channel],
      :category_id => e.find_first('category[@lang="en"]').content,
      :title => e.find_first('title[@lang="ja_JP"]').content,
      :description => e.find_first('desc[@lang="ja_JP"]').content,
      :start => parseDateTime(e.attributes[:start]),
      :end => parseDateTime(e.attributes[:stop])
    }
    #p e.find_first('display-name').content
  end

end

if __FILE__ == $0
  # TODO Generated stub
  create_table()
  import("tmp/epgdump_output_sample.xml")
  
  
end