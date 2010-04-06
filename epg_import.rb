require 'rubygems'
require 'xml/libxml'
require 'sequel'
require 'date'
require 'digest/md5'
require 'nkf'

class String
  def to_han()
    NKF.nkf('-Z1wW', self).tr('　', ' ')
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
  def self.create_init_data()
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
    index :type
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
    unique [:type, :channel]
  end
  
  def self.create_init_data()
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
    integer :category_id, :null => false
    datetime :start, :null => false
    datetime :end, :null => false
    string :hash, :size => 32, :fixed => true, :unique => true, :null => false
    string :title, :size => 512
    string :description, :size => 512
    index [:channel_id, :start, :end]
  end
  
  def set_element(e)
    ch = Channel.find(e.attributes[:channel])
    if ch != nil
      self[:channel_id] = ch[:id]
    end
    
    cate = Category.find(e.find_first('category[@lang="en"]').content)
    if cate == nil
      Category << {
        :type => e.find_first('category[@lang="en"]').content,
        :name => e.find_first('category[@lang="ja_JP"]').content
      }
      cate = Category.find(e.find_first('category[@lang="en"]').content)
    end
    self[:category_id] = cate[:id]
    
    self[:title] = e.find_first('title[@lang="ja_JP"]').content
    self[:description] = e.find_first('desc[@lang="ja_JP"]').content
    self[:start]= parseDateTime(e.attributes[:start])
    self[:end] = parseDateTime(e.attributes[:stop])
    self
  end
  
  def self.populate(e)
    pg = Program.new
    pg.set_element(e)
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
    Program.filter((:channel_id == self[:channel_id]) & (:start < self[:start]) & (:end > self[:end]))
  end
  
  def find
    Program.filter(:hash => self.create_hash)
  end
end

class Reservation < Sequel::Model(:reservations)
  set_schema do
    primary_key :id
    integer :channel_id
    integer :category_id
    string :keyword, :size => 512
    string :hash, :size => 32, :fixed => true
    string :folder, :size => 128
  end
end

class Record < Sequel::Model(:records)
  set_schema do
    primary_key :id
    integer :program_id, :unique => true, :null => true
    integer :reservation_id, :null => true
    string :filename, :unique => true, :null => true
    #enum :state, :elements => ['reserve', 'scheduled', 'recording', 'done', 'removed']
    string :state, :size => 20, :null => true
  end
end

def create_table()
  if !ChannelType.table_exists?
    ChannelType.create_table
    ChannelType.create_init_data()
  end
  if !Channel.table_exists?
    Channel.create_table
    Channel.create_init_data()
  end
  if !Category.table_exists?
    Category.create_table
  end
  if !Program.table_exists?
    Program.create_table
  end
  if !Reservation.table_exists?
    Reservation.create_table
  end
  if !Record.table_exists?
    Record.create_table
  end
end

def parseDateTime(str)
  DateTime.strptime(str, "%Y%m%d%H%M%S")
end

def import(filename)
  
  doc = XML::Document.file(filename)

  pgElems = doc.root.find('//tv/programme')
  maxprog = pgElems.length
  progress = 1
  pgElems.each do |e|
    pg = Program.populate(e)
    next if pg.unknown_channel?
    
    if pg.find.count == 0
      dupPrograms = pg.find_duplicate
      if dupPrograms.count > 0
        # remove duplicate programs
        p 'remove ' + dupPrograms.count.to_s + ' program(s).'
        dupPrograms.all do |r|
          r.delete
        end
      end
      pg.save
    else
      # update program
      #p 'update ' + pg.create_hash
      pg = pg.find.first
      pg.set_element(e)
      pg.save
    end
    if progress % 20 == 0
      p 'import ' + progress.to_s + '/' + maxprog.to_s
    end
    progress = progress + 1
  end
  
  p 'import ' + maxprog.to_s + ' program(s) done.'
end

if __FILE__ == $0
  # TODO Generated stub
  create_table()
  import("tmp/epgdump_GR20_1_sample.xml")
  import("tmp/epgdump_GR20_2_sample.xml")
  import("tmp/epgdump_BS101_1_sample.xml")
  
  
end