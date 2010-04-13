
SETTINGS = {
  :tunners => [
    {:name => "GR0", :type => "GR", :device_name => "PT2"},
    {:name => "GR1", :type => "GR", :device_name => "PT2"},
    {:name => "BS0", :type => "BS/CS", :device_name => "PT2"},
    {:name => "BS1", :type => "BS/CS", :device_name => "PT2"},
  ],
  :channel_types => [
    {:type => "GR", :name => "�n��g", :tunner_type => "GR"},
    {:type => "BS", :name => "BS", :tunner_type => "BS/CS"},
    {:type => "CS", :name => "CS", :tunner_type => "BS/CS"},
  ],
  :channels => [
    #GR
    { :type => 'GR', :channel => '27', :name => 'NHK�����E����' },
    { :type => 'GR', :channel => '26', :name => 'NHK����E����' },
    { :type => 'GR', :channel => '25', :name => '���e��' },
    { :type => 'GR', :channel => '22', :name => 'TBS' },
    { :type => 'GR', :channel => '21', :name => '�t�W�e���r' },
    { :type => 'GR', :channel => '24', :name => '�e���r����' },
    { :type => 'GR', :channel => '23', :name => '�e���r����' },
    { :type => 'GR', :channel => '20', :name => 'TOKYO MX' },
    { :type => 'GR', :channel => '28', :name => '������w' },
    #BS
    { :type => 'BS', :channel => '101', :name => 'NHK BS1' },
    { :type => 'BS', :channel => '102', :name => 'NHK BS2' },
    { :type => 'BS', :channel => '103', :name => 'NHK BSh' },
    { :type => 'BS', :channel => '141', :name => 'BS���e��' },
    { :type => 'BS', :channel => '151', :name => 'BS����' },
    { :type => 'BS', :channel => '161', :name => 'BS-i' },
    { :type => 'BS', :channel => '171', :name => 'BS�W���p��' },
    { :type => 'BS', :channel => '181', :name => 'BS�t�W' },
    { :type => 'BS', :channel => '191', :name => 'WOWOW' },
    { :type => 'BS', :channel => '192', :name => 'WOWOW2' },
    { :type => 'BS', :channel => '193', :name => 'WOWOW3' },
    { :type => 'BS', :channel => '211', :name => 'BS11' },
    { :type => 'BS', :channel => '222', :name => 'TwellV' },
  ]
}

DB = Sequel.connect("sqlite://test.db", {:encoding=>"utf8"})

Sequel.default_timezone = :local

