#!/usr/bin/ruby

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

DB = Sequel.connect("sqlite://test.db", {:encoding=>"utf8"})

Sequel.default_timezone = :local
Sequel::Model.plugin(:schema)
Sequel::Model.plugin(:hook_class_methods )

class Tunner < Sequel::Model(:tunners)
  set_schema do
    primary_key :id
    string :name, :size => 128, :null => false, :unique => true
    string :type, :size => 20, :null => false
    string :device_name, :size => 20, :null => false
  end
  def self.create_init_data()
    Tunner << {:name => "GR0", :type => "GR", :device_name => "PT2"}
    Tunner << {:name => "GR1", :type => "GR", :device_name => "PT2"}
    Tunner << {:name => "BS0", :type => "BS/CS", :device_name => "PT2"}
    Tunner << {:name => "BS1", :type => "BS/CS", :device_name => "PT2"}
  end
end

class ChannelType < Sequel::Model(:channel_types)
  set_schema do
    primary_key :id
    string :type, :size => 20, :null => false, :unique => true
    string :name, :size => 128, :null => false
    string :tunner_type, :null => false
  end
  #one_to_many
  def tunners
    Tunner.filter(:type => self[:tunner_type]).order(:id).all
  end
  
  def self.create_init_data()
    ChannelType << {:type => "GR", :name => "地上波", :tunner_type => "GR"}
    ChannelType << {:type => "BS", :name => "BS", :tunner_type => "BS/CS"}
    ChannelType << {:type => "CS", :name => "CS", :tunner_type => "BS/CS"}
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
  
  def self.types_hash
    Hash[*Category.all.collect{|r| [r[:type], r[:id] ]}.flatten]
  end
end

class Channel < Sequel::Model(:channels)
  set_schema do
    primary_key :id
    string :type, :size => 20, :null => false
    string :channel, :size => 10, :null => false
    string :name, :size => 128
    datetime :update_time
    unique [:type, :channel]
  end
  #many_to_one
  def channel_type
    ChannelType.filter(:type => self[:type]).first
  end
  
  def self.create_init_data()
    #GR
    Channel << { :type => 'GR', :channel => '27', :name => 'NHK総合・東京' }
    Channel << { :type => 'GR', :channel => '26', :name => 'NHK教育・東京' }
    Channel << { :type => 'GR', :channel => '25', :name => '日テレ' }
    Channel << { :type => 'GR', :channel => '22', :name => 'TBS' }
    Channel << { :type => 'GR', :channel => '21', :name => 'フジテレビ' }
    Channel << { :type => 'GR', :channel => '24', :name => 'テレビ朝日' }
    Channel << { :type => 'GR', :channel => '23', :name => 'テレビ東京' }
    Channel << { :type => 'GR', :channel => '20', :name => 'TOKYO MX' }
    Channel << { :type => 'GR', :channel => '28', :name => '放送大学' }
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

  def self.channel_hash
    Hash[*Channel.all.collect{|r| [r.channel_key, r[:id] ]}.flatten]
  end
  
  def channel_key
    self[:type]+self[:channel]
  end
  
  def update_program
    self[:update_time] = Time.now
    save
  end
  
  def find_empty_tunner(start_time, end_time)
    channel_type.tunners.each do |t|
      r = Record.exclude(:program_id => nil).
        eager_graph(:tunner).filter(:tunner__id => t.id).
        eager_graph(:program).filter((:program__start_time < start_time) & (:program__end_time > end_time))
      return t if r.count == 0
    end
    nil
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
  one_to_one :record
  
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
  
  def find_empty_tunner
    channel.find_empty_tunner(self[:end_time], self[:start_time])
  end
  
  def reserve(reservation_id=nil)
    raise "already reserved." if record != nil
    t = find_empty_tunner
    raise "no empty #{channel.channel_type[:type]} tunner." if t == nil
    if record == nil
      Record << {
        :program_id => pk,
        :reservation_id => reservation_id,
        :tunner_id => t.id,
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
  
  def duration_second
    (self[:end_time] - self[:start_time])
  end
  
  def duration
    h = (duration_second / 3600).to_i
    m = ((duration_second % 3600) / 60).to_i
    s = ((duration_second % 3600) % 60).to_i
    (h==0?'':h.to_s+'h') + (m==0?'':m.to_s+'m') + (s==0?'':s.to_s+'s')
  end
  
  def print_line(verbose=false)
    print "#{(record==nil)?'  ':'* '}"
    print "#{self[:id].to_s.rjust(6)} #{channel.channel_key.ljust(5)} "
    print "#{category[:type].ljust(12)} #{self[:start_time].format_display} #{('('+duration+')').ljust(8)} "
    print "#{self[:title]}\n"
    if verbose
      puts "#{'-'.rjust(30)} #{self[:end_time].format_display}"
      puts '      ' + self[:description]
    end
  end
  
  def self.now_onair
    now = Time.now
    Program.filter((:start_time <= now) & (:end_time >= now)).order(:channel_id).all
  end

  def self.search(opt)
    ds = Program.dataset
    if opt[:channel_id] != nil
      ds = ds.filter(:channel_id => opt[:channel_id])
    end
    if opt[:category_id] != nil
      ds = ds.filter(:category_id => opt[:category_id])
    end
    if opt[:keyword] != nil
      kw = opt[:keyword].split(' ').collect{|s| s.strip}.select{|s| s != ''}
      kw.each do |s|
        sl = '%' + s + '%'
        ds = ds.filter((:title.like(sl)) | (:description.like(sl)) )
      end
    end
    if !opt[:all]
      ds = ds.filter(:end_time > Time.now)
    end
    ds
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
  
  def search
    Program.search(values)
  end
  
  def condition?
    !(self[:channel_id] == nil and self[:category_id] == nil and keywords.length == 0)
  end
  
  def self.create(opt)
    self.new({:channel_id => opt[:channel_id], :category_id => opt[:category_id], :keyword => opt[:keyword]}, true)
  end
  
  def self.update_reserve
    order(:id).each do |rs|
      rs.search.all.each do |pg|
        next if pg.record != nil
        #p 'update record reserve. pg:'+ pg.pk.to_s + ' rs' + rs.pk.to_s
        pg.reserve(rs.pk)
      end
    end
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
    integer :program_id, :unique => true, :null => false
    integer :reservation_id
    integer :tunner_id, :null => false
    string :filename, :unique => true, :null => false
    #enum :state, :elements => ['reserve', 'waiting', 'recording', 'done', 'cancel']
    string :state, :size => 20, :null => false, :default => RESERVE
    integer :job
  end
  many_to_one :program
  many_to_one :reservation
  many_to_one :tunner
  
  def reserve?
    state == RESERVE
  end
  def waiting?
    state == WAITING
  end
  
  def self.search(opts)
    #{:program_id => nil, :channel_id => nil, :category_id => nil, :tunner_type => nil}
    ds = Record.dataset
    ds = ds.eager_graph(:program)
    if opts[:tunner_type] != nil
      ds = ds.eager_graph(:tunner).filter(:tunner__type => opts[:tunner_type])
    end
    if opts[:channel_id] != nil
      ds = ds.filter(:program__channel_id => opts[:channel_id])
    end
    if opts[:category_id] != nil
      ds = ds.filter(:program__category_id => opts[:category_id])
    end
    if !opts[:all]
      ds = ds.filter(:program__end_time > Time.now)
    end
    ds.order(:program__start_time)
  end
end

class Torec
  def self.create_table()
    if !Tunner.table_exists?
      Tunner.create_table
      Tunner.create_init_data()
    end
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
  
  def self.import_from_file(filename)
    doc = XML::Document.file(filename)
    progress = import(doc)
    progress[:file] = filename
    progress
  end
  def self.import_from_io(io)
    doc = XML::Document.io(io)
    progress = import(doc)
    progress[:file] = 'io'
    progress
  end

  def self.import(doc)
    pgElems = doc.root.find('//tv/programme')
    maxprog = pgElems.length
    progress = {
      :file => nil, :all => pgElems.length,
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
  
  EPGDUMP = File.join(File.dirname($0), 'do-epgget.sh')
  
  def self.update_epg
    bs =  Channel.filter(:type => 'BS')
    if bs.count != 0
      puts "BS"
      if bs.first.find_empty_tunner(Time.now, Time.now + 190) != nil
        IO.popen("#{EPGDUMP} BS 211 180 2>/dev/null") do |io|
          p import_from_io(io)
        end
        bs.all.each do |r|
          r.update_program
        end
      end
    end
    Channel.filter(:type => 'GR').order(:channel).all.each do |r|
      puts r.channel_key
      next if r.find_empty_tunner(Time.now, Time.now + 70) == nil
      IO.popen("#{EPGDUMP} #{r[:type]} #{r[:channel]} 60") do |io|
        p import_from_io(io)
      end
      r.update_program
    end
    Reservation.update_reserve
  end
end

if __FILE__ == $0
  # TODO Generated stub
  Torec.create_table()
  
  opts = OptionParser.new
  case ARGV.shift
    when 'epgupdate'
      Torec.update_epg
    when 'import'
      opts.program_name = $0 + ' import'
      opts.on("-f", "--file XMLFILE"){|f| p Torec.import_from_file(f) }
      opts.parse!(ARGV)
      Reservation.update_reserve
    when 'search'
      opt = {:channel_id => nil, :category_id => nil, :keyword => nil, :verbose => false, :reserve => false, :now => false, :all => false}
      opts.program_name = $0 + ' search'
      opts.on("--channel CHANNEL", Channel.channel_hash){|cid| opt[:channel_id] = cid }
      opts.on("--category CATEGORY", Category.types_hash){|cid| opt[:category_id] = cid }
      opts.on("--all", "display all records."){opt[:all] = true }
      opts.on("-n", "--now", "display now on-air programs"){opt[:now] = true }
      opts.on("-v", "--verbose", "display program description"){opt[:verbose] = true }
      opts.on("-r", "--reserve", "add auto-recording reserve"){opt[:reserve] = true }
      opts.permute!(ARGV)
      if opt[:now]
        Program.now_onair.each do |r|
          r.print_line(opt[:verbose])
        end
        exit
      end
      opt[:keyword] = ARGV.join(' ')
      rsv = Reservation.create(opt)
      if !rsv.condition?
        puts opts.help
        puts "Channels;"
        Channel.order(:type,:channel).each do |r|
          puts "   #{r.channel_key.ljust(15)} #{r[:name]}"
        end
        puts "Categories;"
        Category.order(:type).each do |r|
          puts "   #{r[:type].ljust(15)} #{r[:name]}"
        end
        exit
      end
      if opt[:reserve]
        rsv = Reservation.new(rsv.values)
        rsv.save
        Reservation.update_reserve
      else
        result = Program.search(opt).order(:start_time).all
        result.each do |r|
          r.print_line(opt[:verbose])
        end
      end
    when 'reserve'
      opt = {:reserve_id => nil}
      opts.program_name = $0 + ' reserve'
      opts.on("--delete RESERVE_ID", Integer, "simple recording"){|rid| opt[:reserve_id] = rid }
      opts.permute!(ARGV)
      if opt[:reserve_id] != nil
        rs = Reservation[opt[:reserve_id]]
        raise "reservation not found." if rs == nil
        rs.delete
        exit
      end
      Reservation.order(:id).each do |r|
        ch = r.channel
        cate = r.category
        puts "#{r[:id].to_s.ljust(6)} #{((ch==nil)?'':ch.channel_key).ljust(6)} #{((cate==nil)?'':cate[:type]).ljust(12)} #{r.keyword}"
      end
    when 'record'
      opt = {:program_id => nil, :channel_id => nil, :category_id => nil, :tunner_type => nil, :all => false}
      opts.program_name = $0 + ' program'
      opts.on("--channel CHANNEL", Channel.channel_hash){|cid| opt[:channel_id] = cid }
      opts.on("--category CATEGORY", Category.types_hash){|cid| opt[:category_id] = cid }
      opts.on("--tunner TUNNER_TYPE", "simple recording"){|type| opt[:tunner_type] = type }
      opts.on("--all", "display all records."){opt[:all] = true }
      opts.on("--add PROGRAM_ID", Integer, "simple recording"){|pid| opt[:program_id] = pid }
      opts.permute!(ARGV)
      if opt[:program_id] != nil
        pg = Program[opt[:program_id]]
        raise "program not found." if pg == nil
        pg.reserve
        exit
      end
      Record.search(opt).all.each do |rc|
        r = rc.program
        print "#{r[:id].to_s.rjust(6)} #{r.channel.channel_key.ljust(5)} "
        print "#{r.category[:type].ljust(12)} #{r[:start_time].format_display} #{('('+r.duration+')').ljust(7)} "
        print "#{r[:title]}\n"
        rid = rc[:reservation_id]
        puts " + #{(rid==nil)?' ':'A'} #{rc[:state].upcase.ljust(6)} #{rc[:filename]}"
      end
  else
    opts.program_name = $0 + ' COMMAND'
    puts opts.help
    puts "  import     "
    puts "  search     "
    puts "  reserve    "
    puts "  record     "
  end
  
end
