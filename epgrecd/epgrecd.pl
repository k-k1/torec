#!/usr/bin/perl -w
# 漢字
use strict;
use Data::Dumper;
use Sys::Syslog;
use Proc::Daemon;
use Getopt::Long;
use POSIX;
use Encode;
use IPC::Run;
use MythTV;

# 標準出力文字コード
binmode STDOUT, ":encoding(euc-jp)";

#####
# TODO:
# mpg or mp4
# TS -> PS
# recfx2_2nd

##############################################
# Setting.

my $program_name    = "epgrecord"; # syslogのプログラム名称

my $recording_dir   = "/tmp";       # MythTVの録画ファイル配置ディレクトリ
my $lib_dir         = "/usr/local/lib/extrec"; # 録画関連コマンド配置ディレクトリ
my $path_epgdump	= "$lib_dir/epgdump";          # epgdump ファイルパス
my $path_mythfill	= "/usr/bin/mythfilldatabase";          # mythfilldatabase ファイルパス
my $path_recfriio   = "$lib_dir/recfriio";     # Friio録画コマンド ファイルパス
my $path_recpt1     = "$lib_dir/recpt1";     # PT1録画コマンド ファイルパス



# 拡張子定義
my $ext_myth   = ".mpg";   # MythTV録画ファイル
my $ext_encts  = ".m2e";   # epgrecord録画ファイル(暗号化状態)
my $ext_ts     = ".m2ts";   # epgrecord録画ファイル(復号化後)
my $ext_mp4    = ".m2t";   # .mp4拡張子
my $ext_isext  = ".isext"; # .isextファイル
my $ext_xml  = ".xml"; # .isextファイル

# オフセットの定義
# 録画開始については、FX2でファームウエアがロードされた場合、再認識待ちで5秒間待たされることに注意。
my $start_offset = -180; # 録画開始時間のオフセット(3分前にチェック)
my $recsec = 60; # 録画時間
my $end_offset = 0; # 録画開始時間のオフセット(3分前にチェック)

# 録画後に実行するコマンド(長くなるので別定義)
my $postprocess = cmd_composite(
	\&cmd_mythtv,   # mythtv登録
);

my $USERJOB1 = 0x0100; # MythTVユーザージョブ1
my $USERJOB2 = 0x0200; # MythTVユーザージョブ2
my $USERJOB3 = 0x0400; # MythTVユーザージョブ3
my $USERJOB4 = 0x0800; # MythTVユーザージョブ4

my $putjob_checkcol = "autouserjob1"; # recordedテーブルのこのカラムが1であればジョブを実行する。
my $putjob_type = $USERJOB2; # job2
my $putjob_host = "clw";     # ジョブ実行ホスト名

# チューナーの定義
my @tuners = (
	# PT1(BS)用定義
	{
		# 名称(未使用)
		name => "PT1BS-1",
		# 対応するMythTVのcardid。
		# MythWebのこれからの録画で一番左に表示される数値。
		# MythTVのスキーマにあるcapturecardテーブルのcardid。
		cardid => 1,
		# 録画前に実行するコマンド
		preprocess  => \&cmd_nop,
		# 録画後に実行するコマンド
		postprocess => $postprocess,
		# 録画コマンド
		reccmd      => \&cmd_recpt1,
		# MythTVのチャンネルから、lircで送信するコマンド列への変換テーブル
		# チャンネルは、channelテーブルのchannumです。
		freqtable   => {
			101  => "101", # NHK
			102  => "102", # NHK
			103  => "103", # BS-Hi
			141  => "141", # BS日テレ
			151  => "151", # BS朝日
			161  => "161", # BS-i
			171  => "171", # BS-japan
			181  => "181", # BS-FUJI
			211  => "211", # BS11
		},
		sourceid => 2,
		mythopt   => {
			101  => "/BS", # NHK
			102  => "/BS", # NHK
			103  => "/BS", # BS-Hi
			141  => "/BS", # BS日テレ
			151  => "/BS", # BS朝日
			161  => "/BS", # BS-i
			171  => "/BS", # BS-japan
			181  => "/BS", # BS-FUJI
			211  => "/BS", # BS11
		},
	},
	# PT1(BS)用定義
	{
		# 名称(未使用)
		name => "PT1BS-0",
		# 対応するMythTVのcardid。
		# MythWebのこれからの録画で一番左に表示される数値。
		# MythTVのスキーマにあるcapturecardテーブルのcardid。
		cardid => 2,
		# 録画前に実行するコマンド
		preprocess  => \&cmd_nop,
		# 録画後に実行するコマンド
		postprocess => $postprocess,
		# 録画コマンド
		reccmd      => \&cmd_recpt1,
		# MythTVのチャンネルから、lircで送信するコマンド列への変換テーブル
		# チャンネルは、channelテーブルのchannumです。
		freqtable   => {
			101  => "101", # NHK
			102  => "102", # NHK
			103  => "103", # BS-Hi
			141  => "141", # BS日テレ
			151  => "151", # BS朝日
			161  => "161", # BS-i
			171  => "171", # BS-japan
			181  => "181", # BS-FUJI
			211  => "211", # BS11
		},
		sourceid => 2,
		mythopt   => {
			101  => "/BS", # NHK
			102  => "/BS", # NHK
			103  => "/BS", # BS-Hi
			141  => "/BS", # BS日テレ
			151  => "/BS", # BS朝日
			161  => "/BS", # BS-i
			171  => "/BS", # BS-japan
			181  => "/BS", # BS-FUJI
			211  => "/BS", # BS11
		},
	},
	# PT1(ISDB-T0)用定義
	{
		# 名称(未使用)
		name => "ISDB-T0",
		# 対応するMythTVのcardid。
		# MythWebのこれからの録画で一番左に表示される数値。
		# MythTVのスキーマにあるcapturecardテーブルのcardid。
		cardid => 3,
		# 録画前に実行するコマンド
		preprocess  => \&cmd_nop,
		# 録画後に実行するコマンド
		postprocess => $postprocess,
		# 録画コマンド
		reccmd      => \&cmd_recpt1,
		# MythTVのチャンネルから、UHFのチャンネル番号への変換テーブル
		# チャンネルは、channelテーブルのchannumです。
		freqtable   => { # channum => freq
			1  => "27", # NHK
			3  => "26", # ETV
			4  => "25", # NTV
			5  => "20", # MX
			6  => "22", # TBS
			8  => "21", # CX
			10 => "24", # EX
			11 => "32", # TVS
			12 => "23", # TX
		},
		sourceid => 1,
		mythopt => {
			1  => "0031.ontvjapan.com", # NHK
			3  => "0041.ontvjapan.com", # ETV
			4  => "0004.ontvjapan.com", # NTV
			6  => "0005.ontvjapan.com", # TBS
			8  => "0006.ontvjapan.com", # CX
			10 => "0007.ontvjapan.com", # EX
			11 => "0012.ontvjapan.com", # TVS
			12 => "0008.ontvjapan.com", # TX
		},
	},
	# ISDB-T2用定義
	{
		# 名称(未使用)
		name => "ISDB-T1",
		# 対応するMythTVのcardid。
		# MythWebのこれからの録画で一番左に表示される数値。
		# MythTVのスキーマにあるcapturecardテーブルのcardid。
		cardid => 4,
		# 録画前に実行するコマンド
		preprocess  => \&cmd_nop,
		# 録画後に実行するコマンド
		postprocess => $postprocess,
		# 録画コマンド
		reccmd      => \&cmd_recpt1,
		# MythTVのチャンネルから、UHFのチャンネル番号への変換テーブル
		# チャンネルは、channelテーブルのchannumです。
		freqtable   => { # channum => freq
			1  => "27", # NHK
			3  => "26", # ETV
			4  => "25", # NTV
			5  => "20", # MX
			6  => "22", # TBS
			8  => "21", # CX
			10 => "24", # EX
			11 => "32", # TVS
			12 => "23", # TX
		},
		sourceid => 1,
		mythopt => {
			1  => "0031.ontvjapan.com", # NHK
			3  => "0041.ontvjapan.com", # ETV
			4  => "0004.ontvjapan.com", # NTV
			6  => "0005.ontvjapan.com", # TBS
			8  => "0006.ontvjapan.com", # CX
			10 => "0007.ontvjapan.com", # EX
			11 => "0012.ontvjapan.com", # TVS
			12 => "0008.ontvjapan.com", # TX
		},
	},
	# Friio用定義
	{
		# 名称(未使用)
		name => "Friio",
		# 対応するMythTVのcardid。
		# MythWebのこれからの録画で一番左に表示される数値。
		# MythTVのスキーマにあるcapturecardテーブルのcardid。
		cardid => 5,
		# 録画前に実行するコマンド
		preprocess  => \&cmd_nop,
		# 録画後に実行するコマンド
		postprocess => $postprocess,
		# 録画コマンド
		reccmd      => \&cmd_recfriio,
		# MythTVのチャンネルから、UHFのチャンネル番号への変換テーブル
		# チャンネルは、channelテーブルのchannumです。
		freqtable   => { # channum => freq
			1  => "27", # NHK
			3  => "26", # ETV
			4  => "25", # NTV
			5  => "20", # MX
			6  => "22", # TBS
			8  => "21", # CX
			10 => "24", # EX
			11 => "32", # TVS
			12 => "23", # TX
		},
		sourceid => 1,
		mythopt => {
			1  => "0031.ontvjapan.com", # NHK
			3  => "0041.ontvjapan.com", # ETV
			4  => "0004.ontvjapan.com", # NTV
			6  => "0005.ontvjapan.com", # TBS
			8  => "0006.ontvjapan.com", # CX
			10 => "0007.ontvjapan.com", # EX
			11 => "0012.ontvjapan.com", # TVS
			12 => "0008.ontvjapan.com", # TX
		},
	},
	# 黒Friio用定義
	{
		# 名称(未使用)
		name => "Friio4",
		# 対応するMythTVのcardid。
		# MythWebのこれからの録画で一番左に表示される数値。
		# MythTVのスキーマにあるcapturecardテーブルのcardid。
		cardid => 8,
		# 録画前に実行するコマンド
		preprocess  => \&cmd_nop,
		# 録画後に実行するコマンド
		postprocess => $postprocess,
		# 録画コマンド
		reccmd      => \&cmd_recfriio,
		# MythTVのチャンネルから、lircで送信するコマンド列への変換テーブル
		# チャンネルは、channelテーブルのchannumです。
		freqtable   => {
			101  => "B10", # NHK
			102  => "B10", # NHK
			103  => "B11", # BS-Hi
			141  => "B8", # BS日テレ
			151  => "B1", # BS朝日
			161  => "B2", # BS-i
			171  => "B4", # BS-japan
			181  => "B9", # BS-FUJI
		},
		sourceid => 2,
		mythopt   => {
			101  => "/BS", # NHK
			102  => "/BS", # NHK
			103  => "/BS", # BS-Hi
			141  => "/BS", # BS日テレ
			151  => "/BS", # BS朝日
			161  => "/BS", # BS-i
			171  => "/BS", # BS-japan
			181  => "/BS", # BS-FUJI
			211  => "/BS", # BS11
		},
	},
);

##############################################
# Initializer.

my $daemon_mode  = 1;                     # daemonとして起動する。
my $pidfile      = "/var/run/mythtv/epgrecd.pid"; # pidfile
GetOptions(
	'daemon!'   => \$daemon_mode,
	'pidfile=s' => \$pidfile,
);

my $last_scheduled_time = 0;
my $schedule_interval = 24 * 60; # (30Sec)
my @invoked_schedules = ();

my %tuners_card_hash = map { ($_->{cardid}, $_) } @tuners;
my @current_schedule = ();

my $interrupted = 0;

$SIG{CHLD} = sub { wait };
$SIG{INT}  = \&interrupt;
$SIG{TERM} = \&interrupt;
$SIG{HUP}  = \&interrupt_hup;

Proc::Daemon::Init if $daemon_mode;

# open Syslog
open_syslog();

syslog("info", "startup.");

eval {
	if ($daemon_mode && $pidfile) {
		open PID, "> $pidfile" or die "can't create pid file: $!";
		print PID "$$\n";
		close PID;
	}
	print "START";
	mainloop();
};
my $err = $@;
if ($err) {
	# died
	eval { syslog("LOG_ERR", "died $err"); };
}

syslog("LOG_INFO", "exit."); 

# close Syslog
close_syslog();

exit 0;
##############################################
# Signal handler.

# TERM, INT時処理
sub interrupt() {
	$interrupted = 1;
}

# HUP時処理
sub interrupt_hup() {
	$last_scheduled_time = 0; # リセット
}

##############################################
# Callbacks

# do nothing callback
sub cmd_nop {
	return 1;
}

# composite
sub cmd_composite {
	my (@child) = @_;
	
	return sub {
		my ($p) = @_;
		for my $c (@child) {
			$c->($p);
		}
	}
}

# recfriio
sub cmd_recpt1($) {
	my ($p) = @_;
	
	my $basename = get_record_basename($p);
	syslog("LOG_INFO", "recfriio $basename start.");

	# basename定義
	$p->{basename} = $basename;

	# 録画時間
	my $now     = time();
	my $endtime = $p->{'endtime'} + $end_offset;
	die "record time must be > 0" if $recsec <= 0;
	
	# UHFチャネル
	my $channum    = $p->{channum};
	my $table      = $p->{tuner}{freqtable};
	die "channum is null" if !defined $channum || "" eq $channum;
	die "unknown channum '$channum'" if ! exists $table->{$channum};
	
	my $uhfchannel = $table->{$channum};
	die "unknown channum '$channum'" if !defined $uhfchannel || "" eq $uhfchannel;

	# 出力
	my $target_encts = "$recording_dir/" . get_record_basename($p) . $ext_encts;
	die "target file '$target_encts' already exists." if -e $target_encts;
	
	# turn on isext flag
	# exec
	my $recout = "";
	my @reccmd = ($path_recpt1, $uhfchannel, $recsec, $target_encts);
	IPC::Run::run \@reccmd, '>&', \$recout or die "exec recfriio failed: $?, Output:$recout";
	
	syslog("LOG_INFO", "recfriio $basename end. Output:$recout");
}

# recfriio
sub cmd_recfriio($) {
	my ($p) = @_;
	
	my $basename = get_record_basename($p);
	syslog("LOG_INFO", "recfriio $basename start.");

	# basename定義
	$p->{basename} = $basename;

	# 録画時間
	my $now     = time();
	my $endtime = $p->{'endtime'} + $end_offset;
	die "record time must be > 0" if $recsec <= 0;
	
	# UHFチャネル
	my $channum    = $p->{channum};
	my $table      = $p->{tuner}{freqtable};
	die "channum is null" if !defined $channum || "" eq $channum;
	die "unknown channum '$channum'" if ! exists $table->{$channum};
	
	my $uhfchannel = $table->{$channum};
	die "unknown channum '$channum'" if !defined $uhfchannel || "" eq $uhfchannel;

	# 出力
	my $target_encts = "$recording_dir/" . get_record_basename($p) . $ext_encts;
	die "target file '$target_encts' already exists." if -e $target_encts;
	
	# turn on isext flag
	# exec
	my $recout = "";
	my @reccmd = ($path_recfriio, $uhfchannel, $recsec, $target_encts);
	IPC::Run::run \@reccmd, '>&', \$recout or die "exec recfriio failed: $?, Output:$recout";
	
	syslog("LOG_INFO", "recfriio $basename end. Output:$recout");
}

# b25 decode callback
sub cmd_mythtv($) {
	my ($p) = @_;
	
	my $basename = get_record_basename($p);
	syslog("LOG_INFO", "recfriio $basename start.");

	# basename定義
	$p->{basename} = $basename;

	my $sourceid    = $p->{sourceid};
	my $table      = $p->{tuner}{mythopt};
	my $channum    = $p->{channum};
	my $uhfchannel = $table->{$channum};
	
	my	$recout = "" ;
	# 出力
	my $target_encts = "$recording_dir/" . get_record_basename($p) . $ext_encts;
	my $dest = "$recording_dir/" .  get_record_basename($p) . $ext_xml ;
	my @epgcmd    = ($path_epgdump, $uhfchannel, $target_encts, $dest);
	syslog("LOG_INFO", "epgdump:" . join(" ", @epgcmd));
	IPC::Run::run \@epgcmd, '>&', \$recout or die "epg failed: $?, Output:$recout";
	
	my @mythcmd    = ($path_mythfill, "--file", $sourceid, $dest);
	syslog("LOG_INFO", "mythfilldatabase :" . join(" ", @mythcmd));
	IPC::Run::run \@mythcmd, '>&', \$recout or die "mythfilldatabase failed: $?, Output:$recout";
	unlink $target_encts or die "can't delete encts '$target_encts':$?";
	unlink $dest or die "can't delete encts '$dest':$?";
	
	syslog("LOG_INFO", "mythtv $basename end.");

	return 1;
}


##############################################
# Code.

sub open_syslog {
	openlog("$program_name", 'pid', "LOG_USER");
}

sub close_syslog {
	closelog();
}

sub mainloop {
	while(!$interrupted) {
		my $now = time();
		if ($last_scheduled_time + $schedule_interval <= $now) {
			# スケジュールのキャッシュを更新
			my @filterd_schedule = get_current_schedule();
			@filterd_schedule = filter_schedule_tuner(@filterd_schedule);
			@filterd_schedule = add_tuner_info(@filterd_schedule);
			$last_scheduled_time = $now;
			@current_schedule = @filterd_schedule;
			
			syslog("LOG_INFO", "schedule cache refreshed. " . @current_schedule . " program(s) scheduled.");
		}
		
		# TODO: @invoked_scheduleが肥大化する問題
		
		my @to_invoke = filter_schedule_time($now, @current_schedule);
		for my $p (@to_invoke) {
			invoke_record($p);
			push @invoked_schedules, $p;
		}
		
		my $nexttime = get_nexttime($now, @current_schedule);
		last if $interrupted;
		syslog("LOG_INFO", "next time: " . localtime($nexttime));
		eval {
			local $SIG{HUP}  = sub { interrupt_hup(); die "SIGHUP"; };
			die "SIGHUP" if $last_scheduled_time == 0; 
			sleep($nexttime - time());
		};
		if ($@) {
			syslog("LOG_INFO", $@);
		}
	}
}

# 実行
sub invoke_record($) {
	my ($p) = @_;
	my $base = get_record_basename($p);
	syslog("LOG_INFO", "invoke: " . get_record_basename($p));
	close_syslog();
	
	my $child_pid = fork;
	if ($child_pid || !defined $child_pid) {
		# 親
		my $serr = $?;

		open_syslog();
		if (!defined $child_pid) {
			die "fork failed for $base: $serr";
		}
	} else {
		openlog("$program_name(record)", 'pid', "LOG_USER");

		$SIG{CHLD} = 'DEFAULT';
		$SIG{INT}  = 'DEFAULT';
		$SIG{TERM} = 'DEFAULT';
		$SIG{HUP}  = 'DEFAULT';

		syslog("LOG_INFO", "record process for $base start.");
		eval {
			record_process($p);
		};
		my $err = $@;
		if ($err) {
			syslog("LOG_ERR", "error in record process for $base: $err");
		}
		eval {
			syslog("LOG_INFO", "record process for $base end.");
			closelog();
		};
		exit 0;
	}
}

# record process
sub record_process($) {
	my ($p) = @_;

	$p->{tuner}{preprocess}($p);
	$p->{tuner}{reccmd}($p);
	$p->{tuner}{postprocess}($p);
}

# timeに録画するスケジュール抽出
sub filter_schedule_time($@) {
	my ($time, @sched) = @_;
	
	my @filterd = @sched;
	# 時刻フィルタ
	@filterd = grep { $_->{'starttime'} + $start_offset <= $time && $time < $_->{'endtime'} + $end_offset } @filterd;
	# 起動済フィルタ
	@filterd = grep { !is_invoked($_) } @filterd;
	# ファイル存在フィルタ
	@filterd = grep {
		my $basename = $recording_dir . "/" . get_record_basename($_);
		!-e "$basename$ext_encts" && !-e "$basename$ext_ts";
	} @filterd;
	
	return @filterd;
}

# 次の時刻を取得する。
sub get_nexttime($@) {
	my ($time, @sched) = @_;
	
	# 後で起動対象になるプログラムのリスト生成
	my @filterd = @sched;
	# 時刻フィルタ
	@filterd = grep { $_->{'starttime'} + $start_offset > $time } @filterd;
	# 起動済フィルタ
	@filterd = grep { !is_invoked($_) } @filterd;
	# ファイル存在フィルタ
	@filterd = grep {
		my $basename = $recording_dir . "/" . get_record_basename($_);
		!-e "$basename$ext_encts" && !-e "$basename$ext_ts";
	} @filterd;
	
	my $nexttime = $last_scheduled_time + $schedule_interval; # デフォルト
	for my $p (@filterd) {
		my $ptime = $p->{'starttime'} + $start_offset;
		$nexttime = $ptime if $ptime < $nexttime;
	}
	
	return $nexttime;
}

# 録画ファイル名(拡張子なし)を取得する。
sub get_record_basename($) {
	my ($p) = @_;
	return "$p->{chanid}_" . strftime("%Y%m%d%H%M%S", localtime($p->{starttime}));
}

# スケジュールの一致判定
sub program_equal($$) {
	my ($a, $b) = @_;
	
	my $ret = 1;
	$ret &&= $a->{cardid}    eq $b->{cardid};
	$ret &&= $a->{chanid}    eq $b->{chanid};
	$ret &&= $a->{starttime} eq $b->{starttime};
	$ret &&= $a->{endtime}   eq $b->{endtime};
	
	return $ret;
}

# @invoked_schedulesに含まれるか？
sub is_invoked($) {
	my ($p) = @_;
	
	my @f = grep { program_equal($p, $_) } @invoked_schedules;
	return scalar(@f);
}

# スケジュールにチューナ情報を付加
sub add_tuner_info(@) {
	my (@in) = @_;
	return map { $_->{tuner} = $tuners_card_hash{$_->{cardid}}; $_ } @in;
}

# @tuner のスケジュールのみ抽出
sub filter_schedule_tuner(@) {
	my (@sched) = @_;
	
	my @filterd = @sched;
	@filterd = grep { exists $tuners_card_hash{$_->{cardid}} } @filterd;
	@filterd = grep { my $stat = $MythTV::RecStatus_Types{$_->{recstatus}}; 'WillRecord' eq $stat || 'Recording' eq $stat } @filterd;
	
	return @filterd;
}

# スケジュール取得
sub get_current_schedule() {
	# 接続/スケジュール取得
	my $mythtv     = new MythTV();
	my %allpending = $mythtv->backend_rows("QUERY_GETALLPENDING", 2);
	$mythtv->backend_command("DONE");
	
	# 余分な物
	my $is_confricts = $allpending{offset}[0];
	my $sched_len    = $allpending{offset}[2];
	
	# Unicode調整 + 結果パース
	my @sched        = map { my @e = map { utf8::decode($_); $_ } @{$_}; new MythTV::Program(@e) } @{$allpending{rows}};
	# パースした結果と、開始／終了のずれをチェックする
	my $connect = $mythtv->{'dbh'};
	for my $s (@sched) {
		my $startoff;
		my $endoff;
		my $sql = "SELECT startoffset, endoffset FROM record WHERE recordid=$s->{recordid}";
		my $query_handle = $connect->prepare($sql);
		$query_handle->execute() || die "Cannot connect to database \n";

		# BIND TABLE COLUMNS TO VARIABLES
		$query_handle->bind_columns(undef, \$startoff, \$endoff);
		# LOOP THROUGH RESULTS
		$query_handle->fetch();
		$s->{'starttime'} = $s->{'starttime'} - ($startoff * 60);
		$s->{'endtime'}  = $s->{'endtime'} +  ($endoff * 60);
		$query_handle->finish();
	}
	$connect->disconnect();
	return @sched;
}

