# -*- encoding: utf-8 -*-

SETTINGS = {
  :tunners => [
    {:name => "GR0", :type => "GR", :device_name => "PT2"},
    {:name => "GR1", :type => "GR", :device_name => "PT2"},
    {:name => "BS0", :type => "BS/CS", :device_name => "PT2"},
    {:name => "BS1", :type => "BS/CS", :device_name => "PT2"},
  ],
  :channel_types => [
    {:type => "GR", :name => "地上波", :tunner_type => "GR"},
    {:type => "BS", :name => "BS", :tunner_type => "BS/CS"},
   #{:type => "CS", :name => "CS", :tunner_type => "BS/CS"},
  ],
  :channels => [
    #GR
    { :type => 'GR', :channel => '27', :name => 'NHK総合・東京' },
    { :type => 'GR', :channel => '26', :name => 'NHK教育・東京' },
    { :type => 'GR', :channel => '25', :name => '日テレ' },
    { :type => 'GR', :channel => '22', :name => 'TBS' },
    { :type => 'GR', :channel => '21', :name => 'フジテレビ' },
    { :type => 'GR', :channel => '24', :name => 'テレビ朝日' },
    { :type => 'GR', :channel => '23', :name => 'テレビ東京' },
    { :type => 'GR', :channel => '20', :name => 'TOKYO MX' },
    { :type => 'GR', :channel => '28', :name => '放送大学' },
    #BS
    { :type => 'BS', :channel => '101', :name => 'NHK BS1' },
    { :type => 'BS', :channel => '102', :name => 'NHK BS2' },
    { :type => 'BS', :channel => '103', :name => 'NHK BSh' },
    { :type => 'BS', :channel => '141', :name => 'BS日テレ' },
    { :type => 'BS', :channel => '151', :name => 'BS朝日' },
    { :type => 'BS', :channel => '161', :name => 'BS-i' },
    { :type => 'BS', :channel => '171', :name => 'BSジャパン' },
    { :type => 'BS', :channel => '181', :name => 'BSフジ' },
    { :type => 'BS', :channel => '191', :name => 'WOWOW' },
    { :type => 'BS', :channel => '192', :name => 'WOWOW2' },
    { :type => 'BS', :channel => '193', :name => 'WOWOW3' },
    #{ :type => 'BS', :channel => '200', :name => 'スター・チャンネルBS' },
    { :type => 'BS', :channel => '211', :name => 'BS11' },
    { :type => 'BS', :channel => '222', :name => 'TwellV' },
    #TODO CS
  ],
  :epgdump_channel_id => {
    #BS
    '3001.ontvjapan.com' => 'BS101',
    '3002.ontvjapan.com' => 'BS102',
    '3003.ontvjapan.com' => 'BS103',
    '3004.ontvjapan.com' => 'BS141',
    '3005.ontvjapan.com' => 'BS151',
    '3006.ontvjapan.com' => 'BS161',
    '3007.ontvjapan.com' => 'BS171',
    '3008.ontvjapan.com' => 'BS181',
    '3009.ontvjapan.com' => 'BS191',
    '3010.ontvjapan.com' => 'BS192',
    '3011.ontvjapan.com' => 'BS193',
    '3012.ontvjapan.com' => 'BS200',
    '3013.ontvjapan.com' => 'BS211',
    '3014.ontvjapan.com' => 'BS222',
    #TODO CS
  },
  # recording SID setting (all,hd,sd1,sd2,sd3,1seg,..)
  :default_record_sid => 'hd',
  :sid_replace_channels => {
    #'GR21' => '1seg',
    'BS101' => '101',
    'BS102' => '102',
    'BS191' => '191',
    'BS192' => '192',
    'BS193' => '193',
  },
  # dir setting
  :output_path => '/home/k1/video',
  :recorder_program_path => '/usr/local/bin/recpt1',
  :log_output_path => File.join(APP_DIR, "log")
}

FileUtils.mkdir_p(SETTINGS[:log_output_path]) unless File.exist?(SETTINGS[:log_output_path])
LOG = Logger.new(File.join(SETTINGS[:log_output_path], "torec.log"), 7, 10 * 1024 * 1024)
LOG.level = Logger::DEBUG
LOG.progname='init'

DB = Sequel.connect("sqlite://" + File.join(APP_DIR, "torec.sqlite3"), {:encoding=>"utf8"})
DB.logger = LOG

Sequel.default_timezone = :local

