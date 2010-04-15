
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
#    {:type => "CS", :name => "CS", :tunner_type => "BS/CS"},
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
    { :type => 'BS', :channel => '211', :name => 'BS11' },
    { :type => 'BS', :channel => '222', :name => 'TwellV' },
  ],
  :application_path => '/home/k1/torec',
  :output_path => '/data/record/',
  :recorder_program_path => '/usr/local/bin/recpt1',
}

#DB = Sequel.connect("sqlite://test.db", {:encoding=>"utf8"})
DB = Sequel.connect("sqlite://#{SETTINGS[:application_path]}/torec.sqlite3", {:encoding=>"utf8"})

Sequel.default_timezone = :local

