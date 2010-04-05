require 'rubygems'
require 'xml/libxml'
require 'sequel'
require 'date'
require 'digest/md5'

class String
  def to_han()
    s = tr('０-９','0-9').tr('ａ-ｚＡ-Ｚ','a-zA-Z')
    s.tr('　',' ')
  end
end

DB = Sequel.connect("sqlite://test.db")

Sequel::Model.plugin(:schema)

class ChannelType < Sequel::Model(:channel_types)
  set_schema do
    primary_key :id
    string :type, :size => 20, :null => false, :unique => true
    string :name, :size => 128, :null => false
  end
  def self.init_channel_types()
    ChannelType << {:type => "GR", :name => "地上波"}
    ChannelType << {:type => "BS", :name => "BS"}
    ChannelType << {:type => "CS", :name => "CS"}
  end
end

class Category < Sequel::Model(:categories)
  set_schema do
    primary_key :id
    string :type, :size => 20, :null => false
    string :name, :size => 128, :null => false
  end
  
  def self.find(type)
    self.filter(:type => type).first
  end
end

class Channel < Sequel::Model(:channels)
  set_schema do
    primary_key :id
    string :type, :size => 20, :null => false
    string :channel, :size => 10, :null => false
    string :name, :size => 128
    #unique :type, :channel
  end
  
  def self.init_channels()
    #GR
    Channel << { :type => 'GR', :channel => '27', :name => 'ＮＨＫ総合１・東京' }
    Channel << { :type => 'GR', :channel => '26', :name => 'ＮＨＫ教育１・東京' }
    Channel << { :type => 'GR', :channel => '25', :name => '日テレ１' }
    Channel << { :type => 'GR', :channel => '22', :name => 'ＴＢＳ１' }
    Channel << { :type => 'GR', :channel => '21', :name => 'フジテレビ' }
    Channel << { :type => 'GR', :channel => '24', :name => 'テレビ朝日' }
    Channel << { :type => 'GR', :channel => '23', :name => 'テレビ東京１' }
    Channel << { :type => 'GR', :channel => '20', :name => 'ＴＯＫＹＯ　ＭＸ１' }
    Channel << { :type => 'GR', :channel => '28', :name => '放送大学１' }
    #BS
    Channel << { :type => 'BS', :channel => '101', :name => 'NHK BS1' }
    Channel << { :type => 'BS', :channel => '102', :name => 'NHK BS2' }
    Channel << { :type => 'BS', :channel => '103', :name => 'NHK BSh' }
    Channel << { :type => 'BS', :channel => '141', :name => 'BS日テレ' }
    Channel << { :type => 'BS', :channel => '151', :name => 'BS朝日' }
    Channel << { :type => 'BS', :channel => '161', :name => 'BS-i' }
    Channel << { :type => 'BS', :channel => '171', :name => 'BSジャパン' }
    Channel << { :type => 'BS', :channel => '181', :name => 'BSフジ' }
    Channel << { :type => 'BS', :channel => '191', :name => 'WOWOW' }
    Channel << { :type => 'BS', :channel => '192', :name => 'WOWOW2' }
    Channel << { :type => 'BS', :channel => '193', :name => 'WOWOW3' }
    Channel << { :type => 'BS', :channel => '211', :name => 'BS11' }
    Channel << { :type => 'BS', :channel => '222', :name => 'TwellV' }
  end
  
  def self.find(chname)
    self.filter('type || channel = ?', chname).first
  end
end

class Program < Sequel::Model(:programs)
  set_schema do
    primary_key :id
    integer :channel_id, :null => false
    integer :category_id, :size => 20, :null => false
    datetime :start, :null => false
    datetime :end, :null => false
    string :hash, :size => 32 ,:null => false
    string :title, :size => 512
    string :description, :size => 512
  end
  
  def self.populate(e)
    pg = Program.new
    
    ch = Channel.find(e.attributes[:channel])
    if ch != nil
      pg[:channel_id] = ch[:id]
    end
    
    cate = Category.find(e.find_first('category[@lang="en"]').content)
    if cate == nil
      Category << {
        :type => e.find_first('category[@lang="en"]').content,
        :name => e.find_first('category[@lang="ja_JP"]').content
      }
      cate = Category.find(e.find_first('category[@lang="en"]').content)
    end
    pg[:category_id] = cate[:id]
    
    pg[:title] = e.find_first('title[@lang="ja_JP"]').content
    pg[:description] = e.find_first('desc[@lang="ja_JP"]').content
    pg[:start]= parseDateTime(e.attributes[:start])
    pg[:end] = parseDateTime(e.attributes[:stop])
    pg
  end
  
  def create_hash
    str = self[:channel_id].to_s + self[:start].to_s + self[:end].to_s
    Digest::MD5.hexdigest(str)
  end
  
  def save
    self[:hash] = self.create_hash
    super
  end
  
  def unknown_channel?
    self[:channel_id] == nil
  end
  
  def find_duplicate()
    Program.filter((:channel_id == self[:channel_id]) & (:start <= self[:start]) & (:end >= self[:end]))
  end
end

def create_table()
  if !ChannelType.table_exists?
    ChannelType.create_table
    ChannelType.init_channel_types()
  end
  if !Channel.table_exists?
    Channel.create_table
    Channel.init_channels()
  end
  if !Category.table_exists?
    Category.create_table
  end
  if !Program.table_exists?
    Program.create_table
  end
end

def parseDateTime(str)
  DateTime.strptime(str, "%Y%m%d%H%M%S")
end

def import(filename)
  
  doc = XML::Document.file(filename)

  doc.root.find('//tv/programme').each do |e|
    pg = Program.populate(e)
    next if pg.unknown_channel?
    
    dupPrograms = pg.find_duplicate
    if dupPrograms.count == 1 && dupPrograms.first[:start] == startdate
      p 'updated.'
      DB[:programs].filter(:id => dupPrograms.first[:id]).update(:start => startdate, title => e.find_first('title[@lang="ja_JP"]').content)
    else
      p 'remove ' + dupPrograms.count.to_s + ' program(s).'
      dupPrograms.all do |r|
        # remove duplicate programs
        r.delete
      end
      pg.save
    end
  end

end

if __FILE__ == $0
  # TODO Generated stub
  create_table()
  import("tmp/epgdump_GR20_1_sample.xml")
  import("tmp/epgdump_GR20_2_sample.xml")
  import("tmp/epgdump_BS101_1_sample.xml")
  
  
end