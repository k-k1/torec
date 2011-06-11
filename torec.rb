#!/usr/bin/ruby
# -*- encoding: utf-8 -*-

#require 'rubygems'
require 'xml/libxml'
require 'sequel'
require 'date'
require 'digest/md5'
require 'nkf'
require 'optparse'
require 'fileutils'
require 'logger'

APP_DIR=File.expand_path(File.dirname($0))
require File.join(APP_DIR, 'torec_settings.rb')

class String
  def to_han()
    NKF.nkf('-Z1 -w -W8', self)
  end
  def parse_date_time
    DateTime.strptime(self, "%Y%m%d%H%M%S %z")
  end
  def nopadding
    self.gsub(/^\s*/, '')
  end
end

class Time
  def format
    self.strftime("%Y%m%d%H%M%S")
  end
  def format_display
    self.strftime("%Y/%m/%d %H:%M:%S")
  end
  INTERVAL = 0.1
  def wait
    loop do
      break if self <= Time.now
      sleep(INTERVAL) 
    end
  end
end

Sequel::Model.plugin(:schema)
Sequel::Model.plugin(:hook_class_methods )

module InitData
  def create_init_data()
    return if SETTINGS[table_name] == nil
    SETTINGS[table_name].each do |h|
      create(h)
    end
  end
end

class Tunner < Sequel::Model(:tunners)
  extend InitData
  set_schema do
    primary_key :id
    string :name, :size => 128, :null => false, :unique => true
    string :type, :size => 20, :null => false
    string :device_name, :size => 20, :null => false
  end
end

class ChannelType < Sequel::Model(:channel_types)
  extend InitData
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

  def self.types
    ChannelType.all.collect{|r| r[:type]}
  end
  
  def find_empty_tunner(start_time, end_time)
    tunners.each do |t|
      r = Record.exclude(:program_id => nil).
        eager_graph(:tunner).filter(:tunner__id => t.id).
        eager_graph(:program).filter{(:program__start_time < start_time) & (:program__end_time > end_time)}
      return t if r.count == 0
    end
    nil
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
  extend InitData
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
  
  def self.find(channel)
    self.filter('type || channel = ?', channel).first
  end

  def self.channel_hash
    Hash[*Channel.all.collect{|r| [r.channel_name, r[:id] ]}.flatten]
  end
  
  def channel_name
    self[:type]+self[:channel].to_s
  end
  
  def update_program
    self[:update_time] = Time.now
    save
  end
  
  def epgdump_commandline(duration)
    ch = SETTINGS[:epgdump_setting][self[:type]][:channel]
    ch = self[:channel] if ch.nil?
    cmdline = ""
    cmdline << SETTINGS[:epgdump_script]
    cmdline << " " << self[:type]
    cmdline << " " << ch.to_s
    cmdline << " " << duration.to_s
    cmdline << ' 2>/dev/null'
    LOG.debug cmdline
    cmdline
  end
  
  def update_target?
    tch = SETTINGS[:epgdump_setting][self[:type]][:channel]
    return true if tch.nil?
    tch == self[:channel].to_s
  end
  
  def update_epg
    if not update_target?
      LOG.debug "ignore"
      return
    end
    result = nil
    duration = SETTINGS[:epgdump_setting][self[:type]][:duration]
    if channel_type.find_empty_tunner(Time.now, Time.now + duration + 10) == nil
      LOG.warn "empty tinner not found."
      return
    end
    IO.popen(epgdump_commandline(duration)) do |io|
      result = import_from_io(io)
      LOG.info result
    end
    update_program
    result
  end
  
  def import_from_file(filename)
    doc = XML::Document.file(filename)
    progress = import(doc)
    progress[:file] = filename
    progress
  end
  def import_from_io(io)
    doc = XML::Document.io(io)
    progress = import(doc)
    progress[:file] = 'io'
    progress
  end

  def import(doc)
    pgElems = doc.root.find('//tv/programme')
    maxprog = pgElems.length
    progress = {
      :file => nil, :all => pgElems.length,
      :unknown_channel => 0, :insert => 0, :modify => 0, :not_modified => 0
    }
    DB.transaction do
      pgElems.each do |e|
        pg = Program.populate(e)
        if pg.unknown_channel?
          LOG.warn "unknown channel #{pg[:channel]} #{e.attributes[:channel]}"
          progress[:unknown_channel] = progress[:unknown_channel] + 1 
          next
        end
        
        if pg.find.count == 0
          dupPrograms = pg.find_duplicate
          if dupPrograms.count > 0
            # remove duplicate programs
            LOG.info 'remove ' + dupPrograms.count.to_s + ' program(s).'
            dupPrograms.all do |r|
              r.delete_reservation_record
              r.delete
            end
          end
          LOG.debug 'insert ' + pg.create_hash
          pg.save
          progress[:insert] = progress[:insert] + 1 
        else
          # update program
          if pg.update != pg
            LOG.info 'update ' + pg.create_hash
            progress[:modify] = progress[:modify] + 1 
          else
            LOG.debug 'not update ' + pg.create_hash
            progress[:not_modified] = progress[:not_modified] + 1 
          end
        end
      end
    end
    progress
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
    chname = SETTINGS[:epgdump_channel_id][e.attributes[:channel]]
    if chname == nil
      chname = e.attributes[:channel]
    end
    ch = Channel.find(chname)
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
    self[:start_time].format + '_' + channel[:type].to_s + channel[:channel].to_s + '.ts'
  end
  
  def find_empty_tunner
    channel.channel_type.find_empty_tunner(self[:end_time], self[:start_time])
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
      record.delete_job
      record.delete
    end
  end
  
  def duration
    (self[:end_time] - self[:start_time]).to_i
  end
  
  def format_duration
    h = (duration / 3600).to_i
    m = ((duration % 3600) / 60).to_i
    s = ((duration % 3600) % 60).to_i
    (h==0?'':h.to_s+'h') + (m==0?'':m.to_s+'m') + (s==0?'':s.to_s+'s')
  end
  
  def print_line(verbose=false)
    mark = (record==nil)?' ':'*'
    id = self[:id].to_s
    start_time = self[:start_time].format_display
    end_time = self[:end_time].format_display
    duration = '('+format_duration+')'
    print <<-EOF.nopadding
      #{mark} #{id.rjust(6)} #{channel.channel_name.ljust(5)} #{category[:type].ljust(12)} #{start_time} #{duration.ljust(8)} #{self[:title]}
    EOF
    print <<-EOF.nopadding if verbose
      #{channel[:name].rjust(20)} - #{end_time} 
      #{self[:description]}
    EOF
  end
  
  def self.now_onair
    now = Time.now
    Program.filter((:start_time <= now) & (:end_time >= now)).order(:channel_id).all
  end

  def next
    Program.filter(:start_time > Time.now ).filter(:channel_id => self[:channel_id]).order(:start_time).first
  end

  def self.search(opt)
    ds = Program.dataset
    if opt[:channel_id] != nil
      ds = ds.filter(:channel_id => opt[:channel_id])
    end
    if opt[:category_id] != nil
      ds = ds.filter(:category_id => opt[:category_id])
    end
    if opt[:channel_type] != nil
      ds = ds.eager_graph(:channel).filter(:channel__type => opt[:channel_type])
    end
    
    if opt[:keyword] != nil
      kw = opt[:keyword].split(' ').collect{|s| s.strip}.select{|s| s != ''}
      kw.each do |s|
        if s[0..0] == '-'
          sl = '%' + s[1..-1] + '%'
          ds = ds.exclude((:title.like(sl)) | (:description.like(sl)) )
        else
          sl = '%' + s + '%'
          ds = ds.filter((:title.like(sl)) | (:description.like(sl)) )
        end
      end
    end
    if !opt[:all]
      ds = ds.filter(:end_time > Time.now)
    end
    ds
  end
  
  def closed?
    ((self[:end_time] - 60) < Time.now)
  end
  
  def remaining_second
    return 0 if closed?
    now = Time.now
    if self[:start_time] < now
      duration - (self[:start_time] - now).to_i
    else
      duration        
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
  
  def search
    Program.search(values)
  end
  
  def condition?
    !(self[:channel_id] == nil and self[:category_id] == nil and keywords.length == 0)
  end
  
  def self.create(opt)
    self.new({:channel_id => opt[:channel_id], :category_id => opt[:category_id],
        :keyword => opt[:keyword], :folder => opt[:folder]}, true)
  end
  
  def self.update_reserve
    order(:id).each do |rs|
      rs.search.all.each do |pg|
        next if pg.record != nil
        LOG.info 'update record reserve. pg:'+ pg.pk.to_s + ' rs' + rs.pk.to_s
        pg.reserve(rs.pk)
      end
    end
  end
  
  def output_dir
    dir = SETTINGS[:output_path]
    dir = File.join(dir, self[:folder]) if self[:folder] != nil
    dir
  end
  
  def make_output_dir
    FileUtils.mkdir_p(output_dir)
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
    string :job, :size => 30
    integer :recording_pid
    datetime :start_time
    datetime :done_time
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
  def recording?
    state == RECORDING
  end
  def done?
    state == DONE
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
    if opts[:state] != nil
      ds = ds.filter(:state => opts[:state].to_s)
    end
    if !opts[:all]
      ds = ds.filter(:program__end_time > Time.now)
    end
    ds = ds.order(:program__start_time)
    ds
  end
  
  def output_dir
    return reservation.output_dir if reservation != nil
    SETTINGS[:output_path]
  end
  
  def make_output_dir
    FileUtils.mkdir_p(output_dir)
  end
  
  def delete_job
    return if self[:job] == nil
    return if not waiting?
    #FIXME error handling
    system("atrm #{self[:job]} 2>&1")
    self[:job] = nil
    self[:state] = RESERVE
    save
  end

  def cancel
    if reserve?
      self[:job] = nil
      self[:state] = CANCEL
      save
    end
  end

  def schedule
    LOG.info "program_id:#{self[:program_id]} schedule start"
    return if not reserve? and not waiting?
    if program.closed?
      cancel
      return
    end

    if waiting?
      #reschedule
      delete_job
    end
    
    #before 1 minute
    at_start = (program[:start_time] - 60)
    at_start_str = at_start.strftime('%H:%M %m/%d/%Y')
    
    if at_start < Time.now
      at_start_str = 'now'
    end

    jobid = nil
    start_progs = File.join(APP_DIR,'torec.rb') << " record --start " << program.pk
    LOG.info "program_id:#{self[:program_id]} schedule at internal commandline : #{start_progs}"
    
    IO.popen("at #{at_start_str} 2>&1", 'r+') do |io|
      io << start_progs << "\n"
      io.close_write
      io.each do |l|
        next if l.match(/^warning:/)
        jobid = l.split(' ')[1]
        break
      end
    end
    
    self[:filename] = File.join(output_dir, program.create_filename)
    self[:job] = jobid
    self[:state] = WAITING
    save
    LOG.info "program_id:#{self[:program_id]} scheduled. at jobid=#{self[:job]}"
  end

  def stop_recording
    return if not recording?
    begin
      Process.kill(:INT,self[:recording_pid])
      LOG.warn "process killed. #{self[:recording_pid]}"
    rescue
      LOG.warn "process not found. #{self[:recording_pid]}"
    end
  end
  
  def find_prev_record
    ds = Record.dataset
    ds = ds.eager_graph(:program)
    ds = ds.filter(:tunner_id => self[:tunner_id])
    ds = ds.filter(:state => RECORDING) 
    ds = ds.filter(:program__end_time >= program[:start_time])
    ds = ds.order(:program__end_time.desc)
    rc = ds.first
    return nil if rc == nil
    rc[Record.table_name]
  end
  
  def record_sid
    sid = SETTINGS[:default_record_sid]
    return nil if sid.nil?
    
    if SETTINGS[:sid_replace_channels][program.channel.channel_name] != nil
      sid = SETTINGS[:sid_replace_channels][program.channel.channel_name].to_s
    end
    sid
  end
  
  def start
    return if not waiting?
    LOG.info "program_id:#{self[:program_id]} start."
    
    sid = record_sid
    
    args = []
    args << "--b25"
    args << "--strip"
    if not sid.nil?
      args << "--sid" << sid
    end
    #args << "--device" << "/dev/pt1video2"
    args << program.channel[:channel].to_s
    args << (program.remaining_second + 5).to_s
    args << File.join(output_dir, program.create_filename)
    
    make_output_dir
    LOG.debug "program_id:#{self[:program_id]} recorder args:#{args.join(',')}"
    
    #waiting..
    (program[:start_time] - 1).wait
    rc = find_prev_record
    rc.stop_recording if rc != nil
    
    #recording
    pid = Process.fork do
      #child process
      LOG.info "program_id:#{self[:program_id]} start recording process.. pid:#{pid}"
      exec(SETTINGS[:recorder_program_path], *args)
    end
    self[:start_time] = Time.now
    self[:state] = RECORDING
    self[:recording_pid] = pid
    save
    LOG.info "wait recording process.."
    th = Process.detach(pid)
    th.value
    done
    LOG.info "recording done."
  end
  
  def done
    return if not recording?
    self[:done_time] = Time.now
    self[:state] = DONE
    save
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
  
  def self.update_epg(chid = nil)
    LOG.progname='update_epg'
    target_channels = []
    if chid != nil
      target_channels << Channel[:id => chid]
    else
      target_channels = Channel.order(:channel).all
    end
    target_channels.each do |ch|
      next unless ch.update_target?
      puts "update " + ch.channel_name
      LOG.progname="update-" + ch.channel_name
      rs = nil
      rt = 0
      begin
        rt = rt + 1
        rs = ch.update_epg
      rescue => e
        LOG.error e.message
        LOG.debug e.backtrace
        retry if rt < 3
        LOG.error "update failed"
      end
    end
  end
end

if __FILE__ == $0
  # TODO Generated stub
  Torec.create_table()
  
  opts = OptionParser.new
  case ARGV.shift
    when 'update'
      opt = {:file => nil, :channel_id => nil}
      opts.program_name = $0 + ' update'
      opts.on("-f", "--file XMLFILE"){|f| opt[:file] = f; Torec.import_from_file(f) }
      opts.on("-c", "--channel CHANNEL", Channel.channel_hash){|cid| opt[:channel_id] = cid }
      opts.parse!(ARGV)
      Torec.update_epg(opt[:channel_id]) if opt[:file] == nil
      Reservation.update_reserve
    when 'search'
      opt = {:channel_id => nil, :category_id => nil, :channel_type => nil, :keyword => nil,
        :verbose => false, :reserve => false, :folder => nil, :now => false, :next=> false, :all => false}
      opts.program_name = $0 + ' search'
      opts.on("-n", "--now", "display now on-air programs"){opt[:now] = true }
      opts.on("-N", "--next", "display next on-air programs"){opt[:next] = true }
      opts.on("-c", "--channel CHANNEL", Channel.channel_hash){|cid| opt[:channel_id] = cid }
      opts.on("-g", "--category CATEGORY", Category.types_hash){|cid| opt[:category_id] = cid }
      opts.on("-t", "--type CHANNEL_TYPE", ChannelType.types){|cid| opt[:channel_type] = cid }
      opts.on("-a", "--all", "display all records."){opt[:all] = true }
      opts.on("-v", "--verbose", "display program description"){opt[:verbose] = true }
      opts.on("-r", "--reserve", "add condition to auto-recording"){opt[:reserve] = true }
      opts.on("-d", "--dir DIRNAME", "auto-recording save directory"){|d| opt[:folder] = d }
      opts.permute!(ARGV)
      if opt[:now]
        Program.now_onair.each do |r|
          next if opt[:channel_type] != nil and opt[:channel_type] != r.channel[:type]
          r.print_line(opt[:verbose])
        end
        exit
      end
      if opt[:next]
        Program.now_onair.each do |r|
          next if opt[:channel_type] != nil and opt[:channel_type] != r.channel[:type]
          r.next.print_line(opt[:verbose])
        end
        exit
      end
      opt[:keyword] = ARGV.join(' ')
      rsv = Reservation.create(opt)
      if !rsv.condition?
        puts opts.help
        puts "Channels;"
        Channel.order(:type,:channel).each do |r|
          puts "   #{r.channel_name.ljust(15)} #{r[:name]}"
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
      opt = {:reserve_id => nil, :mkdir => false}
      opts.program_name = $0 + ' reserve'
      opts.on("--delete RESERVE_ID", Integer, "delete auto-recording condition"){|rid| opt[:reserve_id] = rid }
      opts.on("--mkdir", "make reserve directories"){ opt[:mkdir] = true }
      opts.permute!(ARGV)
      if opt[:mkdir]
        Reservation.order(:id).each do |r|
          r.make_output_dir
        end
        exit
      end
      if opt[:reserve_id] != nil
        rs = Reservation[opt[:reserve_id]]
        raise "reservation not found." if rs == nil
        rs.delete
        exit
      end
      Reservation.order(:id).each do |r|
        ch = r.channel
        cate = r.category
        puts "#{r[:id].to_s.ljust(6)} #{((ch==nil)?'':ch.channel_name).ljust(6)} #{((cate==nil)?'':cate[:type]).ljust(12)} #{r.keyword}"
      end
    when 'record'
      opt = {:program_id => nil, :channel_id => nil, :category_id => nil, :tunner_type => nil, :all => false, :state => nil}
      opts.program_name = $0 + ' record'
      opts.on("-c", "--channel CHANNEL", Channel.channel_hash){|cid| opt[:channel_id] = cid }
      opts.on("-g", "--category CATEGORY", Category.types_hash){|cid| opt[:category_id] = cid }
      opts.on("-t", "--tunner TUNNER_TYPE"){|type| opt[:tunner_type] = type }
      opts.on("-a", "--all", "display all records."){opt[:all] = true }
      opts.on("--schedule [PROGRAM_ID]", "schedule records."){|pid| opt[:state] = :schedule; opt[:program_id] = pid }
      opts.on("--start PROGRAM_ID"){|pid| opt[:state] = :start; opt[:program_id] = pid }
      opts.on("--add PROGRAM_ID", Integer, "simple recording"){|pid| opt[:state] = :add; opt[:program_id] = pid }
      opts.parse!(ARGV)
      if opt[:program_id] != nil
        pg = Program[opt[:program_id]]
        raise "program not found." if pg == nil
        if opt[:state] == :schedule
          pg.record.schedule
        elsif opt[:state] == :start
          pg.record.start
        elsif opt[:state] == :add
          pg.reserve
        end
        exit
      elsif opt[:state] == :schedule
        opt[:state] = :reserve
        Record.search(opt).all.each do |rc|
          rc.schedule
        end
        exit
      end
      Record.search(opt).all.each do |rc|
        r = rc.program
        print "#{r[:id].to_s.rjust(6)} #{r.channel.channel_name.ljust(5)} "
        print "#{r.category[:type].ljust(12)} #{r[:start_time].format_display} #{('('+r.format_duration+')').ljust(7)} "
        print "#{r[:title]}\n"
        rid = rc[:reservation_id]
        state = rc[:state].upcase
        state = state + ' ' + rc[:job].to_s if rc.waiting?
        puts "   #{(rid==nil)?' ':'A'} #{state.ljust(20)} #{rc[:filename]}"
        if not rc.reserve? and not rc.waiting?
          jid = rc[:job]
          dtime = rc[:done_time]
          puts "#{' '.ljust(25)} #{rc[:start_time].format_display.ljust(20)}- #{((dtime==nil)?'':dtime.format_display).ljust(20)}"
        end
      end
  else
    opts.program_name = $0 + ' COMMAND'
    puts opts.help
    puts "  update     "
    puts "  search     "
    puts "  reserve    "
    puts "  record     "
  end
  
end
