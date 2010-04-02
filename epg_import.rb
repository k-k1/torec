require 'rubygems'
require 'xml/libxml'
require 'sequel'
require 'date'
require 'jcode'

class String
  def to_han()
    s = tr('０-９','0-9').tr('ａ-ｚＡ-Ｚ','a-zA-Z')
    s.tr('　',' ')
  end
end


DB = Sequel.connect("sqlite://test.db")

def create_table()
  if !DB.table_exists?(:channel_types)
    DB.create_table :channel_types do
      primary_key :id
      varchar :type, :size => 20, :null => false
      varchar :name, :size => 128, :null => false
    end
    ct = DB[:channel_types]
    ct << {:type => "GR", :name => "地上波"}
    ct << {:type => "BS", :name => "BS"}
    ct << {:type => "CS", :name => "CS"}
  end
  if !DB.table_exists?(:channels)
    DB.create_table :channels do
      primary_key :id
      varchar :type, :size => 20, :null => false
      varchar :name, :size => 128, :null => false
    end
  end
  if !DB.table_exists?(:categories)
    DB.create_table :categories do
      primary_key :id
      varchar :type, :size => 20, :null => false
      varchar :name, :size => 128, :null => false
    end
  end
  if !DB.table_exists?(:programs)
    DB.create_table :programs do
      primary_key :id
      varchar :channel_id, :size => 20, :null => false
      varchar :category_id, :size => 20, :null => false
      varchar :title, :size => 512
      varchar :description, :size => 512
      datetime :start, :null => false
      datetime :end, :null => false
    end
  end
end

def parseDateTime(str)
  DateTime.strptime(str, "%Y%m%d%H%M%S")
end

def import(filename)
  
  doc = XML::Document.file(filename)
  
  doc.root.find('//tv/channel').each do |e|
    p e.attributes[:id]
    #p e.find_first('display-name').content
#    DB[:channels] << {
#      :category_id => e.find_first('category[@lang="en"]').content.to_han,
#      :title => e.find_first('title[@lang="ja_JP"]').content.to_han,
#      :description => e.find_first('desc[@lang="ja_JP"]').content.to_han,
#      :start => parseDateTime(e.attributes[:start]),
#      :end => parseDateTime(e.attributes[:stop])
#    }
  end

  doc.root.find('//tv/programme').each do |e|
    DB[:programs] << {
      :channel_id => e.attributes[:channel],
      :category_id => e.find_first('category[@lang="en"]').content.to_han,
      :title => e.find_first('title[@lang="ja_JP"]').content.to_han,
      :description => e.find_first('desc[@lang="ja_JP"]').content.to_han,
      :start => parseDateTime(e.attributes[:start]),
      :end => parseDateTime(e.attributes[:stop])
    }
  end

end

if __FILE__ == $0
  # TODO Generated stub
  create_table()
  import("tmp/epgdump_output_sample.xml")
  
  
end