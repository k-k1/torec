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
      string :type, :size => 20, :null => false, :unique => true
      string :name, :size => 128, :null => false
    end
    ct = DB[:channel_types]
    ct << {:type => "GR", :name => "地上波"}
    ct << {:type => "BS", :name => "BS"}
    ct << {:type => "CS", :name => "CS"}
  end
  if !DB.table_exists?(:channels)
    DB.create_table :channels do
      primary_key :id
      string :type, :size => 20, :null => false
      string :channel, :size => 10, :null => false
      string :name, :size => 128
      #unique :type, :channel
    end
    init_channels()
  end
  if !DB.table_exists?(:categories)
    DB.create_table :categories do
      primary_key :id
      string :type, :size => 20, :null => false
      string :name, :size => 128, :null => false
    end
  end
  if !DB.table_exists?(:programs)
    DB.create_table :programs do
      primary_key :id
      string :channel_id, :size => 20, :null => false
      string :category_id, :size => 20, :null => false
      string :title, :size => 512
      string :description, :size => 512
      datetime :start, :null => false
      datetime :end, :null => false
    end
  end
end

def init_channels()
  channels = DB[:channels]
  channels << { :type => 'GR', :channel => '27', :name => 'ＮＨＫ総合１・東京' }
  channels << { :type => 'GR', :channel => '26', :name => 'ＮＨＫ教育１・東京' }
  channels << { :type => 'GR', :channel => '25', :name => '日テレ１' }
  channels << { :type => 'GR', :channel => '22', :name => 'ＴＢＳ１' }
  channels << { :type => 'GR', :channel => '21', :name => 'フジテレビ' }
  channels << { :type => 'GR', :channel => '24', :name => 'テレビ朝日' }
  channels << { :type => 'GR', :channel => '23', :name => 'テレビ東京１' }
  channels << { :type => 'GR', :channel => '20', :name => 'ＴＯＫＹＯ　ＭＸ１' }
  channels << { :type => 'GR', :channel => '28', :name => '放送大学１' }
  
  channels << { :type => 'BS', :channel => '101', :name => 'NHK BS1' }
  channels << { :type => 'BS', :channel => '102', :name => 'NHK BS2' }
  channels << { :type => 'BS', :channel => '103', :name => 'NHK BSh' }
  channels << { :type => 'BS', :channel => '141', :name => 'BS日テレ' }
  channels << { :type => 'BS', :channel => '151', :name => 'BS朝日' }
  channels << { :type => 'BS', :channel => '161', :name => 'BS-i' }
  channels << { :type => 'BS', :channel => '171', :name => 'BSジャパン' }
  channels << { :type => 'BS', :channel => '181', :name => 'BSフジ' }
  channels << { :type => 'BS', :channel => '191', :name => 'WOWOW' }
  channels << { :type => 'BS', :channel => '192', :name => 'WOWOW2' }
  channels << { :type => 'BS', :channel => '193', :name => 'WOWOW3' }
  channels << { :type => 'BS', :channel => '211', :name => 'BS11' }
  channels << { :type => 'BS', :channel => '222', :name => 'TwellV' }
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
#      :category_id => e.find_first('category[@lang="en"]').content,
#      :title => e.find_first('title[@lang="ja_JP"]').content,
#      :description => e.find_first('desc[@lang="ja_JP"]').content,
#      :start => parseDateTime(e.attributes[:start]),
#      :end => parseDateTime(e.attributes[:stop])
#    }
  end

  doc.root.find('//tv/programme').each do |e|
    DB[:programs] << {
      :channel_id => e.attributes[:channel],
      :category_id => e.find_first('category[@lang="en"]').content,
      :title => e.find_first('title[@lang="ja_JP"]').content,
      :description => e.find_first('desc[@lang="ja_JP"]').content,
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