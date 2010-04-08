require 'rubygems'
require 'xml/libxml'
require 'sequel'
require 'date'
require 'digest/md5'
require 'nkf'
require 'optparse'

class String
  def to_han()
    NKF.nkf('-Z1wW', self).tr('　', ' ')
  end
  def parse_date_time
    DateTime.strptime(self, "%Y%m%d%H%M%S")
  end
end

class Time
  def format
    self.strftime("%Y%m%d%H%M%S")
  end
  def format_display
    self.strftime("%Y/%m/%d %H:%M:%S")
  end
end

DB = Sequel.connect("sqlite://test.db")

Sequel::Model.plugin(:schema)
Sequel::Model.plugin(:hook_class_methods )

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
  #fixme
  #many_to_one :channel_type, :key => 'type', :primary_key => 'type'
  
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
    datetime :start_time, :null => false
    datetime :end_time, :null => false
    string :hash, :size => 32, :fixed => true, :null => false
    string :title, :size => 512
    string :description, :size => 512
    index [:channel_id, :start_time, :end_time]
  end
  many_to_one :channel
  many_to_one :category
  one_to_many :records, :one_to_one => :record
  
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
    self[:start_time]= e.attributes[:start].parse_date_time
    self[:end_time] = e.attributes[:stop].parse_date_time
    self
  end
  
  def overwrite(pg)
    [:channel_id, :title, :description, :start_time, :end_time].each do |s|
      self[s] = pg[s]
    end
  end
  
  def self.populate(e)
    pg = Program.new
    pg.set_element(e)
  end
  
  def create_hash
    str = self[:category_id].to_s + self[:title] + self[:description]
    Digest::MD5.hexdigest(str)
  end
  
  before_save do
    self[:hash] = self.create_hash
  end
  
  def unknown_channel?
    self[:channel_id] == nil
  end
  
  def find_duplicate()
    Program.filter((:channel_id == self[:channel_id]) & (:start_time < self[:start_time]) & (:end_time > self[:end_time]))
  end
  
  def find
    Program.filter(:channel_id => self[:channel_id], :start_time => self[:start_time], :end_time => self[:end_time])
  end
  
  def detail_modified?
    oldpg = find.first
    raise "update program not found." if oldpg == nil
    create_hash != oldpg[:hash]
  end
  
  def update
    if detail_modified?
      oldpg = find.first
      oldpg.overwrite(self)
      oldpg.save
      oldpg
    else
      self
    end
  end
  
  def delete_reservation_record
    cancel_reserve
  end
  
  def create_filename
    self[:start_time].format + '_' + channel[:type] + channel[:channel] + '.ts'
  end
  
  def reserve
    if record == nil
      Record << {
        :program_id => pk,
        :filename => create_filename
      }
    end
  end
  
  def cancel_reserve
    return if record == nil
    if record.reserve? or record.waiting?
      #TODO remove at job
      record.delete
    end
  end
end

class Reservation < Sequel::Model(:reservations)
  set_schema do
    primary_key :id
    integer :channel_id
    integer :category_id
    string :keyword, :size => 512
    string :folder, :size => 128
  end
  one_to_many :records
  many_to_one :channel
  many_to_one :category
  
  def keywords
    return [] if self[:keyword] == nil
    self[:keyword].split(' ').collect{|s| s.strip}.select{|s| s != ''}
  end
  
  def search_program_dataset
    ds = Program.dataset
    if self[:channel_id] != nil
      ds = ds.filter(:channel_id => :channel_id)
    end
    if self[:category_id] != nil
      ds = ds.filter(:category_id => :category_id)
    end
    if self[:keyword] != nil
      keywords.each do |s|
        sl = '%' + s + '%'
        ds = ds.filter((:title.like(sl)) | (:description.like(sl)) )
      end
    end
    ds
  end
end

class Record < Sequel::Model(:records)
  RESERVE = 'reserve'
  WAITING = 'waiting'
  RECORDING = 'recording'
  DONE = 'done'
  CANCEL = 'cancel'
  
  set_schema do
    primary_key :id
    integer :program_id, :unique => true, :null => true
    integer :reservation_id
    string :filename, :unique => true, :null => true
    #enum :state, :elements => ['reserve', 'waiting', 'recording', 'done', 'cancel']
    string :state, :size => 20, :null => true, :default => RESERVE
    integer :job
  end
  many_to_one :program
  many_to_one :reservation
  
  def reserve?
    state == RESERVE
  end
  def waiting?
    state == WAITING
  end
end

class Torec
  def self.create_table()
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
  
  def self.import(filename)
    
    doc = XML::Document.file(filename)
    
    pgElems = doc.root.find('//tv/programme')
    maxprog = pgElems.length
    progress = {
      :file => filename, :all => pgElems.length,
      :unknown_channel => 0, :insert => 0, :modify => 0, :not_modified => 0
    }
    pgElems.each do |e|
      pg = Program.populate(e)
      if pg.unknown_channel?
        progress[:unknown_channel] = progress[:unknown_channel] + 1 
        next
      end
      
      if pg.find.count == 0
        dupPrograms = pg.find_duplicate
        if dupPrograms.count > 0
          # remove duplicate programs
          p 'remove ' + dupPrograms.count.to_s + ' program(s).'
          dupPrograms.all do |r|
            r.delete_reservation_record
            r.delete
          end
        end
        pg.save
        progress[:insert] = progress[:insert] + 1 
      else
        # update program
        #p 'update ' + pg.create_hash
        if pg.update != pg
          progress[:modify] = progress[:modify] + 1 
        else
          progress[:not_modified] = progress[:not_modified] + 1 
        end
      end
    end
    
    progress
  end
end

if __FILE__ == $0
  # TODO Generated stub
  Torec.create_table()
  
  opts = OptionParser.new
  if ARGV.length < 1
    puts "TODO help message"
    exit
  end
  case ARGV.shift
    when 'import'
      opts.on("-f", "--file XMLFILE"){|f| p Torec.import(f) }
      opts.parse!(ARGV)
  else
    
  end
  
end