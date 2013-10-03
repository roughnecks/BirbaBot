#!/usr/bin/perl
# -*- mode: cperl -*-

# No copyright
# Written by Marco Pessotto a.k.a. MelmothX
# Contributor: Simone Canaletti a.k.a. roughnecks

# This code is free software; you may redistribute it
# and/or modify it under the same terms as Perl itself.

use strict;
use warnings;
use diagnostics;

# POE
use POE;
use POE::Component::Client::DNS;
use POE::Component::IRC::Common qw(parse_user l_irc irc_to_utf8);
use POE::Component::IRC::Plugin::BotCommand;
use POE::Component::IRC::Plugin::CTCP;
use POE::Component::IRC::State;

# Modules
use Cwd;
use Data::Dumper;
use Date::Parse;
use File::Basename;
use File::Copy;
use File::Path qw(make_path);
use File::Spec;
use File::Temp qw//;
use HTML::Entities;
use HTML::Strip;
use LWP::Simple;
use Storable;
use URI::Find;
use URI::Escape;
use YAML::Any qw/LoadFile/;

# Internal libs
use lib './BirbaBot/lib';
use BirbaBot qw(create_bot_db
		read_config
		override_defaults show_help);
use BirbaBot::RSS qw(
		     rss_add_new
		     rss_delete_feed
		     rss_get_my_feeds
		     rss_give_latest
		     rss_list
		     rss_clean_unused_feeds
		   );
use BirbaBot::Geo;
use BirbaBot::Searches qw(search_google
			  query_meteo
			  yahoo_meteo
			  search_imdb
			  search_bash
			  search_urban
			  get_youtube_title
			);
use BirbaBot::Infos qw(kw_add kw_new kw_query kw_remove kw_list kw_find kw_show kw_delete_item karma_manage);
use BirbaBot::Todo  qw(todo_add todo_remove todo_list todo_rearrange);
use BirbaBot::Notes qw(notes_add notes_give notes_pending anotes_pending notes_del anotes_del);
use BirbaBot::Shorten qw(make_tiny_url);
use BirbaBot::Quotes qw(ircquote_add 
		    ircquote_del 
		    ircquote_rand 
		    ircquote_last 
		    ircquote_find
		    ircquote_num
		    ircquote_list);
use BirbaBot::Tail qw(file_tail);
use BirbaBot::Debian qw(deb_pack_versions deb_pack_search);

# Modules END

our $VERSION = '1.8.3';

use constant {
  USER_DATE     => 0,
  USER_MSG      => 1,
  DATA_FILE     => 'seen',
  SAVE_INTERVAL => 20 * 60, # save state every 20 mins
};

my $seen = { };
$seen = retrieve(DATA_FILE) if -s DATA_FILE;

my @longurls;
my $urifinder = URI::Find->new( sub { # print "Found url: ", $_[1], "\n"; 
				      push @longurls, $_[1]; } );

$| = 1; # turn buffering off

my $lastpinged;

# Before starting, create a pid file

open (my $fh, ">", "birba.pid");
print $fh $$;
close $fh;
undef $fh;

my $reconnect_delay = 120;

my %serverconfig = (
		    'nick' => 'Birba',
		    'ircname' => "Birba the Bot",
		    'username' => 'birbabot',
		    'server' => 'localhost',
		    'localaddr' => undef,
		    'port' => 7000,
		    'usessl' => 1,
		    'useipv6' => undef,
		   );

my %botconfig = (
		 'channels' => ["#lamerbot"],
		 'botprefix' => "@",
		 'rsspolltime' => 600, # default to 10 minutes
		 'dbname' => "bot.db",
		 'admins' => [ 'nobody!nobody@nowhere' ],
		 'adminpwd' => '',
		 'fuckers' => [ 'fucker1',' fucker2'],
		 'nspassword' => 'nopass',
		 'tail' => {},
		 'ignored_lines' => [],
		 'relay_source' => [],
		 'relay_dest' => [],
		 'twoways_relay' => [],
		 'msg_log' => [],
		 'kw_prefix' => '',
		 'psyradio' => '',
		 'psychan' => '',
		);

my %debconfig = (
		'debrels' => [],
		);

# Initialize the local storage
my $localdir = File::Spec->catdir('data','rss');
make_path($localdir) unless (-d $localdir);

my $config_file = $ARGV[0];
my $debug = $ARGV[1];

show_help() unless $config_file;

# Configuration checking 
my ($botconf, $serverconf, $debconf) = LoadFile($config_file);
override_defaults(\%serverconfig, $serverconf);
override_defaults(\%botconfig, $botconf);
override_defaults(\%debconfig, $debconf);


print "Bot options: ", Dumper(\%botconfig),
  "Server options: ", Dumper(\%serverconfig),
  "Debian Releases: ", Dumper(\%debconfig);

my $dbname = $botconfig{'dbname'};
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", "", "",
		       { AutoCommit => 1, 
			 # 'sqlite_unicode' => 1
		       });
$dbh->do('PRAGMA foreign_keys = ON;') or die "Can't operate on the DB\n";
undef $dbname;

my @channels = @{$botconfig{'channels'}};

# Build the regexp of the admins
my @adminregexps = process_admin_list(@{$botconfig{'admins'}});

my @fuckers = @{$botconfig{'fuckers'}};

my $adminpwd = $botconfig{'adminpwd'};
my $relay_source = $botconfig{'relay_source'};
my $relay_dest = $botconfig{'relay_dest'};
my $twoways_relay = $botconfig{'twoways_relay'};
my $msg_log = $botconfig{'msg_log'};
my $ircname = $serverconfig{'ircname'};
my $psyradio = $botconfig{'psyradio'};
my $psychan = $botconfig{'psychan'};
my $debian_relfiles_base = File::Spec->catdir(getcwd(), 'debs');

# When we start, we check if we have all the tables.  By no means this
# guarantees that the tables are correct. Devs, I'm looking at you
create_bot_db($dbh) or die "Errors while updating db tables";

# Be sure that the feeds are in the channels we join
rss_clean_unused_feeds($dbh, \@channels);

my $starttime = time;

my $bbold = "\x{0002}";
my $ebold = "\x{000F}";

# psyradio
my $lastsong;
my $psy_id;
my $psy_chk = 0;

# Starting POE stuff

my $irc = POE::Component::IRC::State->spawn(%serverconfig) 
  or die "WTF? $!\n";

my $dns = POE::Component::Client::DNS->spawn();

POE::Session->create(
		     package_states => [
					main => [ qw(_start
						     _default
						     irc_001 
						     irc_ctcp_action
						     irc_disconnected
						     irc_error
						     irc_join
						     irc_kick
						     irc_msg
						     irc_notice
						     irc_part
						     irc_ping
						     irc_public
						     irc_quit
						     irc_socketerr
						     irc_botcmd_admin
						     irc_botcmd_anotes
						     irc_botcmd_bash
						     irc_botcmd_choose
						     irc_botcmd_cut
						     irc_botcmd_deb
						     irc_botcmd_debsearch
						     irc_botcmd_deop
						     irc_botcmd_devoice
						     irc_botcmd_done
						     irc_botcmd_free
						     irc_botcmd_g
						     irc_botcmd_geoip
						     irc_botcmd_gi
						     irc_botcmd_git
						     irc_botcmd_gv
						     irc_botcmd_gw
						     irc_botcmd_imdb
						     irc_botcmd_isdown
						     irc_botcmd_k
						     irc_botcmd_karma
						     irc_botcmd_kb
						     irc_botcmd_kw
						     irc_botcmd_lookup
						     irc_botcmd_lremind
						     irc_botcmd_math
						     irc_botcmd_meteo
						     irc_botcmd_mode
						     irc_botcmd_note
						     irc_botcmd_notes
						     irc_botcmd_op
						     irc_botcmd_psyradio
						     irc_botcmd_quote
						     irc_botcmd_remind
						     irc_botcmd_restart
						     irc_botcmd_rss
						     irc_botcmd_seen
						     irc_botcmd_slap
						     irc_botcmd_timebomb
						     irc_botcmd_todo
						     irc_botcmd_topic
						     irc_botcmd_uptime
						     irc_botcmd_urban
						     irc_botcmd_version
						     irc_botcmd_voice
						     irc_botcmd_whoami
						     irc_botcmd_wikiz
						     debget_sentinel
						     dns_response
						     greetings_and_die
						     ping_check
						     psyradio_sentinel
						     reminder_del
						     reminder_sentinel
						     rss_sentinel
						     save
						     tail_sentinel
						     timebomb_start) ],
				       ],
		    );

$poe_kernel->run();

sub _start {
  my ($kernel) = $_[KERNEL];
  $irc->plugin_add('BotCommand', 
		   POE::Component::IRC::Plugin::BotCommand->new(
								Commands => {
									     admin => '(admin <pwd>) -- Add yourself as a temporary admin supplying the correct password set in config file; admin privileges will be flushed upon a bot restart - we only accept queries.',
									     anotes => '(anotes [del <nick>]) -- Admin listing and deletion of pending notes: without arguments list all pending notes.',
									     bash => '(bash [<number>]) -- Get a random quote from bash.org or quote number <number>.',
									     choose => '(choose <choice1> <choice2> [<choice#n>]) -- Do a random guess | Takes 2 or more arguments.',
									     cut => '(cut <wire>) -- Timebomb Game: Defuse the Bomb by cutting the right colored wire; see "help timebomb".',
									     deb => '(deb <package_name>) -- Query for versions of given Debian pakage.',
									     debsearch => '(debsearch <string>) -- Find Debian packages matching <string>.',
									     deop => '(deop <nick> [<nick2> <nick#n>]) -- Deop someone in the current channel.',
									     devoice => '(devoice <nick> [<nick2> <nick#n>]) -- Devoice someone in the current channel.',
									     done => '(done <#n>) -- Delete something from the channel TODO; argument must be a number as shown by the list of channel (todo); see "help todo".',
									     free => '(free) -- Show system memory usage.',
									     g => '(g <string to search>) -- Do a google search: Takes a string of one or more arguments as search pattern.',
									     geoip => '(geoip <ip_number|hostname>) -- IP Geolocation | Takes one argument: an ip or a hostname to lookup.',
									     gi => '(gi <string to search>) -- Do a search on google images.',
									     git =>'(git <pull|version>) -- Pull updates from BirbaBot Git Repository or show Git Version.',
									     gv => '(gv <string to search>) -- Do a search on google videos.',
									     gw => '(gw <string to search>) -- Do a search on wikipedia by google',
									     imdb => '(imdb <string|id|link>) -- Query the Internet Movie Database: takes one argument, a generic string or an id/link to fetch more data. ids are strings at the end of an imdb link, like "tt0088247".',
									     k => '(k <nick> [reason]) -- Kick someone from the current channel; reason is not mandatory.',
									     karma => '(karma [<nick>]) -- Get the karma of a user, or yours, without argument.',
									     kb => '(kb <nick> [reason]) -- KickBan someone from the current channel; reason is not mandatory.',
									     kw => '(kw new|add <foo is bar | "foo is bar" is yes, probably foo is bar> | forget <foo> | delete <foo 2/3> | list | show <foo> | find <foo>) - (<!>key) - (key > <nick>) - (key >> <nick>) -- Manage the keywords: new/add, forget, delete, list, find, spit, redirect, query. For special keywords usage please read the doc/Factoids.txt help file.',
									     isdown => '(isdown <domain>) -- Check whether a website is up or down.',
									     lookup => '(lookup [<MX|AAAA>] <host>) -- Query Internet name servers | Takes two arguments: a record type like MX, AAAA (optional), and a host.',
									     lremind => '(lremind) -- List active reminders in current channel, takes no argument.',
									     math => '(math <num> <*|/|%|-|+> <num>) -- Do simple math: operators are " * / % - + ". Example: "math 3 * 3".',
									     meteo => '(meteo >city>) -- Ask the weatherman for location.',
									     mode => '(mode <+|-><mode>) -- Set channels modes, like "mode +R-ks" but also users modes, like bans: "mode +b nick!user@host".',
									     note => '(note <nick> <message>) -- Send a note to a user not in the channel: he/she will get a query next time logins.',
									     notes => '(notes [del <nickname>]) -- Manage your own notes: without arguments lists pending notes by current user. "del" deletes all pending notes from the current user to <nickname>',
									     op => '(op <nick> [<nick2> <nick#n>]) -- Give operator status to the given nick(s) in the current channel.',
									     psyradio => '(psyradio <on | off | status | last>) -- Start or stop psyradio (http://psyradio.com.ua/) titles broadcasting, get info about the service or get the last (current) track. on and off switches require an Op/Admin.',
									     quote => '(quote add <text> | del <number> | <number> | rand | last | find <argument> | list) -- Manage the quotes database.',
									     remind => '(remind [<x> | <xhxm> | <xdxhxm>] <message>) assuming "x" is a number -- Store an alarm for the current user, delayed by "x minutes" or by "xhxm" hours and minutes or by "xdxhxm" days, hours and minutes. Alternate syntax: (<message> -- <date>). <date> accepts a wide variety of formats and an optional ZONE parameter at the end.',
									     restart => '(restart) -- Restart BirbaBot',
									     rss => '(rss [add <name> <url> | del <name> | show <name> | list]) -- Manage RSS subscriptions: RSS add, del, show, list.',
									     seen => '(seen <nick>) -- Search for a user.',
									     slap   => '(slap <nick>) -- Simple Luser Attitude Readjustment Tool, aka "lart".',
									     timebomb => '(timebomb <nick>) -- Timebomb Game: place the bomb on <nick> panties; use cut <wire> to defuse it.',
									     todo => '(todo [add <foo> | rearrange | done <#i>]) -- Manage the channel TODO.',
									     topic => '(topic <topic>) -- Set the channel topic.',
									     uptime => '(uptime) -- Show the Bot\'s uptime',
									     urban => '(urban [url] <foo>) -- Get definitions from the urban dictionary | "urban url <foo>" asks for the url',
									     version => '(version) -- Show our version number and infos.',
									     voice => '(voice <nick> [<nick2> <nick#n>]) -- Give voice status to someone in the current channel.',
									     whoami => '(whoami) -- Check if you have Admin permission in BirbaBot.',
									     wikiz => '(wikiz <foo>) -- Perform a search on "http://laltromondo.dynalias.net/~iki" and retrieve urls matching given argument.'									    },
								In_channels => 1,
								Auth_sub => \&check_if_fucker,
								Ignore_unauthorized => 1,
								In_private => 1,
								Addressed => 0,
								Prefix => $botconfig{'botprefix'},
								Eat => 1,
								Ignore_unknown => 1,
								
							       ));
  $irc->plugin_add( 'CTCP' => POE::Component::IRC::Plugin::CTCP->new(
								     version => "BirbaBot v.$VERSION, IRC Perl Bot: https://github.com/roughnecks/BirbaBot",
								     userinfo => $ircname,
								    ));
  $irc->yield( register => 'all' );
  $irc->yield( connect => { } );
  $kernel->delay_set('save', SAVE_INTERVAL);
  # Here we register the sentinels
  $kernel->delay_set("reminder_sentinel", 35);  # first run after 35 seconds
  $kernel->delay_set("tail_sentinel", 40);  # first run after 40 seconds
  $kernel->delay_set("rss_sentinel", 60);  # first run after 60 seconds
  if (($psyradio) && (! $psy_chk)) {$kernel->delay_set("psyradio_sentinel", 170)};  # first run after 170 seconds
  $kernel->delay_set("ping_check", 180);  # first run after 180 seconds
  $kernel->delay_set("debget_sentinel", 185);  # first run after 185 seconds
  $lastpinged = time();
  return;
}


# We register for all events, this will produce some debug info.
sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    my @output = ( "$event: " );

    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join(', ', @$arg ) . ']' );
        }
        else {
            push ( @output, "'$arg'" ) unless (! $arg);
        }
    }
    print print_timestamp(), join ' ', @output, "\n";
    return 0;
}






###########
###########
# irc_ subs

sub irc_001 {
    my ($kernel, $sender) = @_[KERNEL, SENDER];

    # Since this is an irc_* event, we can get the component's object by
    # accessing the heap of the sender. Then we register and connect to the
    # specified server.
    my $irc = $sender->get_heap();

    print print_timestamp(), "Connected to ", $irc->server_name(), "\n";

    # We join our channels waiting a few secs
    foreach (@channels) {
      $irc->delay( [ join => $_ ], 10 ); 
    }

    return;
}

sub irc_ctcp_action {
  my $nick = parse_user($_[ARG0]);
  my $chan = $_[ARG1]->[0];
  my $text = $_[ARG2];
  # $text = irc_to_utf8($text);

  add_nick($nick, "on $chan doing: * $nick $text");
  
  # debug log                                               
  if ($msg_log == 1) {                                      
    print print_timestamp(), "$chan \| * $nick $text\n";
  }
  # relay stuff
  if (($relay_source) && ($relay_dest)) {
    if ($chan eq $relay_source) {
      foreach ($text) {
	bot_says($relay_dest, "\[$relay_source\]: * $nick $text")
      }
    }
  }
  
  if ( ($twoways_relay == 1) && ($relay_source) && ($relay_dest)) {
    if ($chan eq $relay_dest) {
      foreach ($text) {
	bot_says($relay_source, "\[$relay_dest\]: * $nick $text");
      }
    }
  }
}     
                                                    

sub irc_disconnected {
  print print_timestamp(), "Reconnecting in $reconnect_delay seconds\n";
  $irc->delay([ connect => { }], $reconnect_delay);
}

sub irc_error {
  print print_timestamp(), "Reconnecting in $reconnect_delay seconds\n";
  $irc->delay([ connect => { }], $reconnect_delay);
}

sub irc_join {
    my $nick = parse_user($_[ARG0]);
    my $chan = $_[ARG1];
    my @notes = notes_give($dbh, $nick);
    add_nick($nick, "joining $chan");
    while (@notes) {
      bot_says($nick, shift(@notes));
    }
}

sub irc_kick {
  my $kicker = $_[ARG0];
  my $channel = $_[ARG1];
  my $kicked = $_[ARG2];
  my $botnick = $irc->nick_name;
  return unless $kicked eq $botnick;
  sleep 5;
  $kicker = parse_user($kicker);
  $irc->yield( join => $channel );
  bot_says($channel, "$kicker: :-P");
}

sub irc_msg {
  my ($who, $what) = @_[ARG0, ARG2];
  my $nick = parse_user($who);
  
  # if it's a fucker, do nothing
  my ($auth, $spiterror) = check_if_fucker('null', $who, 'null', $what);
  if (! $auth) {
    print "fucker $who said $what in private\n";
    return;
  }

  if ( $what =~ /^(\Q$botconfig{'kw_prefix'}\E)(.+)\s*$/ ) {
    print "info: requesting keyword $2\n";
    my $kw = $2;
    my $query = (kw_query($dbh, $nick, lc($kw)));
    if (($query) && ($query =~ m/^ACTION\s(.+)$/)) {
      $irc->yield(ctcp => $nick, "ACTION $1");
      return;
    } elsif ($query) {
      bot_says($nick, $query);
    return;
    } 
  } elsif ($what =~ /^[^\Q$botconfig{'botprefix'}\E](.+)\s*$/) {
    print "info: requesting keyword $what\n";
    my $query = (kw_query($dbh, $nick, lc($what)));
    if (($query) && ($query =~ m/^ACTION\s(.+)$/)) {
      $irc->yield(ctcp => $nick, "ACTION $1");
      return;
    } elsif ($query) {
      bot_says($nick, $query);
      return;
    }
  }
}


sub irc_notice {
  my ($who, $text) = @_[ARG0, ARG2];
  my $nick = parse_user($who);
  print "Notice from $who: $text", "\n";
  if ( ($nick eq 'NickServ' ) && ( $text =~ m/^This\snickname\sis\sregistered.+$/ || $text =~ m/^This\snick\sis\sowned\sby\ssomeone\selse\..+$/ ) ) {
    my $passwd = $botconfig{'nspassword'};
    $irc->yield( privmsg => "$nick", "IDENTIFY $passwd");
  }
}

sub irc_part {
    my $nick = parse_user($_[ARG0]);
    my $chan = $_[ARG1];
    my $text = $_[ARG2];

    my $msg = "parting " . $chan;
    $msg .= " with message '$text'" if defined $text;

    add_nick($nick, $msg);
}

sub irc_ping {
  print "Ping!\n";
  $lastpinged = time();
}

sub irc_public {
  my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];
  my $botnick = $irc->nick_name;
  # $what = irc_to_utf8($what);
    
  # debug log
  if ($msg_log == 1) {
    print print_timestamp(), "$channel \| <$nick> $what\n";
  }
  
  # relay stuff
  if (($relay_source) && ($relay_dest)) {
    if ($channel eq $relay_source) {
      foreach ($what) {
	bot_says($relay_dest, "\[$relay_source/$nick\]: $what")
      }
    }
  }
  
  if ( ($twoways_relay == 1) && ($relay_source) && ($relay_dest)) {
    if ($channel eq $relay_dest) {
      foreach ($what) {
	bot_says($relay_source, "\[$relay_dest/$nick\]: $what")
      }
    }
  }
  # seen stuff
  add_nick($nick, "on $channel saying: $what");
  
  # if it's a fucker, do nothing
  my ($auth, $spiterror) = check_if_fucker($sender, $who, $where, $what);
  return unless $auth;
  
  # Let's parse channel messages to find out links and stuff
  chan_msg_parser($what, $nick, $channel, $botnick, $where);
  return;
}

sub irc_quit {
  my $nick = parse_user($_[ARG0]);
  my $text = $_[ARG1];

  my $msg = 'quitting';
  $msg .= " with message '$text'" if defined $text;

  add_nick($nick, $msg);
}

sub irc_socketerr {
  print print_timestamp(), "Reconnecting in $reconnect_delay seconds\n";
  $irc->delay([ connect => { }], $reconnect_delay);
}

# END irc_ subs
###############
###############






##################
##################
# irc_botcmd_ subs

# Game: Timebomb
my %defuse;
my %bomb_active;
my %alarm_active;
 
sub irc_botcmd_admin {
  my ($who, $where, $arg) = @_[ARG0..$#_];
  return if is_where_a_channel($where);
  return if not defined $arg;
  return if $arg =~ m/^\s*$/;
  if ($arg eq $adminpwd) {
    push @adminregexps, qr/^\Q$who\E$/;
    print "Temporary Admin added\n";
    print Dumper(\@adminregexps);
    bot_says($where, "Temporary Admin added.");
    return;
  } else { print "Failed attempt to add a temporary Admin by $who\n"; }
}

sub irc_botcmd_anotes {
  my ($who, $where, $arg) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  unless (check_if_admin($who)) {
    bot_says($where, "You need to be an admin, sorry");
    return;
  }
  if (! defined $arg) {
    bot_says($where, anotes_pending($dbh));
  } elsif ($arg =~ /^\s*$/) {
    bot_says($where, anotes_pending($dbh));
  } else {
    my ($subcmd, $fromwho) = split(/\s+/, $arg);
    if (($subcmd eq 'del') && (defined $fromwho)) {
      bot_says($where, anotes_del($dbh, $fromwho));
      return;
    } else {
      bot_says($where, "Missing or invalid argument");
    }
  }
}

sub irc_botcmd_bash {
  my ($where, $arg) = @_[ARG1, ARG2];
  my $good;
  if (! $arg ) {
    $good = 'random';
  } elsif ( $arg =~ m/^(\d+)/s ) {
    $good = $1;
  } else {
    return;
  }
  my $result = search_bash($good);
  if ($result) {
    foreach (split("\r*\n", $result)) {
      bot_says($where, $_);
    }
  } else {
    bot_says($where, "Quote $good not found");
  }
}

sub irc_botcmd_choose {
  my ($where, $args) = @_[ARG1..$#_];
  my @choises = split(/ +/, $args);
  foreach ( @choises ) {
    $_ =~ s/^\s*$//;
  }
  unless ($#choises > 0) {
    bot_says ($where, 'Provide at least 2 arguments');
  } else {
    my %string = map { $_, 1 } @choises;
    if (keys %string == 1) {
      # all equal
      bot_says($where, 'That\'s an hard guess for sure :P');
    } else {
      my $lenght = scalar @choises;
      my $random = int(rand($lenght));
      bot_says($where, "$choises[$random]");
    }
  }
}

sub irc_botcmd_cut {
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  my @args = split(/ +/, $what);
  my $wire = shift(@args);
  return unless (defined $defuse{$channel});
  if ($wire eq $defuse{$channel}) {
    undef $bomb_active{$channel};
    undef $defuse{$channel};
    bot_says($channel, "Congrats $nick, bomb defused.");
    return
  } else {
    my $target = $nick;
    my $reason = "Booom!";
    pc_kick($botnick, $target, $channel, $botnick, $reason);
    undef $bomb_active{$channel};
    undef $defuse{$channel};
  }
}

sub irc_botcmd_deb {
  my ($where, $arg) = @_[ARG1, ARG2];
  return unless $arg =~ m/\S/;
  my @out = deb_pack_versions($arg,
			      $debian_relfiles_base, 
			      $debconfig{debrels});
  if (@out) {
    bot_says($where, "Package $arg: ". join(', ', @out));
  } else {
    bot_says($where, "No packs for $arg");
  }
}


sub irc_botcmd_debsearch {
  my ($where, $arg) = @_[ARG1, ARG2];
  my $result = deb_pack_search($arg, $debian_relfiles_base, $debconfig{debrels});
  if ($result) {
    bot_says($where, $result);
  } else {
    bot_says($where, "No result found");
  }
}

sub irc_botcmd_deop {
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  return unless (check_if_op($channel, $nick) || check_if_admin($who)) ;
  my @args = "";
  if (! $what) {
    @args = ("$nick");
  } else {
    @args = split(/ +/, $what);
  }
  my $status = '-o';
  pc_status($status, $channel, $botnick, @args);
}

sub irc_botcmd_devoice {
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  return unless (check_if_op($channel, $nick) || check_if_admin($who)) ;
  my @args = "";
  if (! $what) {
    @args = ("$nick");
  } else {
    @args = split(/ +/, $what);
  }
  my $status = '-v';
  pc_status($status, $channel, $botnick, @args);
}

sub irc_botcmd_done {
  my ($who, $chan, $arg) = @_[ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
  #  bot_says($chan, $irc->nick_channel_modes($chan, $nick));
  unless (check_if_op($chan, $nick) or check_if_admin($who)) {
    bot_says($chan, "You're not a channel operator. " . todo_list($dbh, $chan));
    return
  }
  if ($arg =~ m/^([0-9]+)$/) {
    bot_says($chan, todo_remove($dbh, $chan, $1));      
  } else {
    bot_says($chan, "Give the numeric index to delete the todo")
  }
  return;
}

sub irc_botcmd_free {
  my $mask = $_[ARG0];
  my $nick = (split /!/, $mask)[0];
  my $where = $_[ARG1];
  unless (check_if_op($where, $nick) or check_if_admin($mask)) {
    bot_says($where, "You need to be a bot/channel operator, sorry");
    return;
  }
      die "Can't fork: $!" unless defined(my $pid = open(KID, "-|"));
  my %freestats = (
		   total => "n/a",
		   used => "n/a",
		   free => "n/a",
		   swaptot => "n/a",
		   swapused => "n/a",
		   swapfree => "n/a",
		  );
  if ($pid) { # parent
    while (<KID>) {
      my $line = $_;
      if ($line =~ m/^Mem\:\s+(\d+)\s+/) {
	$freestats{total} = $1;
      } elsif ($line =~ m/^\-\/\+ buffers\/cache\:\s+(\d+)\s+(\d+)/) {
	$freestats{used} = $1;
	$freestats{free} = $2;
      } elsif ($line =~ m/^Swap\:\s+(\d+)\s+(\d+)\s+(\d+)/) {
	$freestats{swaptot} = $1;
	$freestats{swapused} = $2;
	$freestats{swapfree} = $3;
      }
    }
    close KID;
    my $output = "Memory: used " . $freestats{used} . "/" . $freestats{total} .
      "MB, " . $freestats{free} . "MB free. Swap: used " . $freestats{swapused} .
	"/" . $freestats{swaptot} . "MB";
    undef %freestats;
    bot_says($where, $output);
    return;
  } else {
    # this is the external process, forking. It never returns
    my @command = ('free', '-m');
    exec @command or die "Can't exec git: $!";
  }
}

sub irc_botcmd_g {
  my ($where, $arg) = @_[ARG1, ARG2];
  return unless is_where_a_channel($where);
  if (($arg) && $arg =~ /^\s*$/) {
    return
  } else {
    bot_says($where, search_google($arg, "web"));
  }
}

sub irc_botcmd_geoip {
  my ($who, $where, $arg) = @_[ARG0, ARG1, ARG2];
  return unless is_where_a_channel($where) || check_if_admin($who);
  $irc->yield(privmsg => $where => BirbaBot::Geo::geo_by_name_or_ip($arg));
  return;
}

sub irc_botcmd_gi {
  my ($where, $arg) = @_[ARG1, ARG2];
  return unless is_where_a_channel($where);
  if (($arg) && $arg =~ /^\s*$/) {
    return
  } else { 
    bot_says($where, search_google($arg, "images"));
  }
}

sub irc_botcmd_git {
  my ($who, $where, $arg) = @_[ARG0, ARG1, ARG2];
  return unless (sanity_check($who, $where));
  return unless $arg;
  if ($arg eq 'pull') { 
    my $gitorigin = `git config --get remote.origin.url`;
    if ($gitorigin =~ m!^\s*ssh://!) {
      bot_says($where, "Your git uses ssh, I can't safely pull");
      return;
    }
    die "Can't fork: $!" unless defined(my $pid = open(KID, "-|"));
    if ($pid) {           # parent
      while (<KID>) {
	bot_says($where, $_);
      }
      close KID;
      return;
    } else {
      my @command = ("git", "pull");
      # this is the external process, forking. It never returns
      exec @command or die "Can't exec git: $!";
    }
    return;
  } elsif ($arg eq 'version') {
    die "Can't fork: $!" unless defined(my $pid = open(KID, "-|"));
    if ($pid) { # parent
      while (<KID>) {
	my $line = $_;
	unless ($line =~ m/^\s*$/) {
	  bot_says($where, $line);
	}
      }
      close KID;
      return;
    } else {
      # this is the external process, forking. It never returns
      my @command = ('git', 'log', '-n', '1');
      exec @command or die "Can't exec git: $!";
    }
  } else {
    bot_says($where, "git command accepts only 'pull' and 'version' subcommands");
    return;
  }
}


sub irc_botcmd_gv {
  my ($where, $arg) = @_[ARG1, ARG2];
  return unless is_where_a_channel($where);
  if (($arg) && $arg =~ /^\s*$/) {
    return
  } else { 
    bot_says($where, search_google($arg, "video"));
  }
}

sub irc_botcmd_gw {
  my ($where, $arg) = @_[ARG1, ARG2];
  return unless is_where_a_channel($where);
  if (($arg) && $arg =~ /^\s*$/) {
    return
  } else {
    my $prefix = 'site:en.wikipedia.org ';
    bot_says($where, search_google($prefix.$arg, "web"));
  }
}

sub irc_botcmd_imdb {
  my ($where, $arg) = @_[ARG1, ARG2];
  if ($arg =~ /^\s*$/) {
    return
  } else {
    bot_says($where, search_imdb($arg));
  }
}

sub irc_botcmd_isdown {
  my ($where, $what) = @_[ARG1, ARG2];
  return unless is_where_a_channel($where);
  if ($what =~ m/^\s*(http\:\/\/)?(\www\.)?([a-zA-Z0-9][\w\.-]+\.[a-z]{2,4})\/?\s*$/) {
    $what = $2 . $3;
    if ($what =~ m/^\s*(www\.)?downforeveryoneorjustme\.com\s*/) {
      bot_says($where, 'You just found egg #1: http://laltromondo.dynalias.net/~img/images/sitedown.png');
      return;
    }
  } else {
    bot_says($where, "Uh?");
    return;
  }
  my $prepend = 'http://www.downforeveryoneorjustme.com/';
  my $query = $prepend . $what;
  #  print "Asking downforeveryoneorjustme for $query\n";
  my $file = get "$query";
  if ( $file =~ m|<div\ id\=\"container\">(.+)</p>|s ) {
    my $result = $1;
    my $hs = HTML::Strip->new();
    my $clean_text = $hs->parse( $result );
    $hs->eof;
    chomp($clean_text);
    $clean_text =~ s/\s+/ /g;
    $clean_text =~ s/^\s+//;
    bot_says($where, $clean_text);
  }
}

sub irc_botcmd_k {
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  return unless (check_if_op($channel, $nick) || check_if_admin($who)) ;
  if (! $what) {
    bot_says($channel, 'lemme know who has to be kicked');
    return;
  } else {
    my @args = split(/ +/, $what);
    my $target = shift(@args);
    my $reason = join (" ", @args);    
    pc_kick($nick, $target, $channel, $botnick, $reason);
  }
}

sub irc_botcmd_karma {
  my ($who, $where, $arg) = @_[ARG0, ARG1, ARG2];
  my $nick = parse_user($who);
  my $botnick = $irc->nick_name;
  my @res;
  if (($arg) && ($arg =~ m/^\s*\S+\s*$/)) {
      $arg =~ s/\s*//g;
      $nick = $arg;
  }
  @res = karma_manage($dbh, $nick);
  my $string;
  if (@res) {
      if ($res[0] eq $botnick) {
          $string = "I have karma $res[1]";
      }
      else {
          $string = "$res[0] has karma $res[1]";
      }
  }
  else {
      $string = "No karma for $nick"
  }
  bot_says($where, $string);
  return;
}

sub irc_botcmd_kb {
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  return unless (check_if_op($channel, $nick) || check_if_admin($who)) ;
  if (! $what) {
    bot_says($channel, 'lemme know who has to be kicked');
    return;
  } else {
    my $mode = '+b';
    my @args = split(/ +/, $what);
    my $target = shift(@args);
    my $reason = join (" ", @args);    
    pc_ban($mode, $channel, $botnick, $target);
    pc_kick($nick, $target, $channel, $botnick, $reason);
  }
}

sub irc_botcmd_kw {
  my ($who, $where, $arg) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  if (! $arg) {
    bot_says($where, "$nick, Missing Arguments: ask me 'help kw'");
    return
  }
  my @args = split(/\s+/, $arg);
  my $subcmd = shift(@args);
  my $string = join (" ", @args);

  # first manage the "easy" subcommands
  # list, no arguments
  if ($subcmd eq 'list') {
    return bot_says($where, kw_list($dbh))
  }

  # other subcommands have arguments, so do the check
  return bot_says($where, "No argument provided") unless $string;
  
  # sanity checks
  if ($subcmd eq 'find') {
    if (is_where_a_channel($where)) {
      return bot_says($where, "$nick, this command works only in a query");
    }
  }

  # prevent the abusing
  if ($subcmd =~ m/^(new|add|delete|forget)$/) {
    return bot_says($where, "This command works only in a channel")
      unless ((is_where_a_channel($where)) or check_if_admin($who)); 
  }
  if ($subcmd eq 'forget') {
    return bot_says($where, "Only admins can make me forget that")
      unless check_if_admin($who);
  }

  # identify the target
  my $target;
  my $definition;
  my $slot;
  # forget, show and find  has 1 argument, verbatim
  if (($subcmd eq 'forget') or
      ($subcmd eq 'show') or
      ($subcmd eq 'find')) {
    $target = lc($string);
  }
  # delete is the same, plus the [#]
  if ($subcmd eq 'delete') {
    if ($string =~ /^\s*(.+)\s+([23])\s*$/) {
      $target = lc($1);
      $slot = $2;
    } else {
      return bot_says($where, "Wrong delete command");
    }
  }

  # new and add has the "is" as separator, unless there are the ""
  if (($subcmd eq 'new') or
      ($subcmd eq 'add')) {
    if ($string =~ m/^\s*"(.+?)"\s+is+(.+)\s*$/) {
      ($target, $definition) = (lc($1), $2);
    } elsif ($string =~ m/^\s*(.+?)\s+is\s+(.+)\s*$/) {
      ($target, $definition) = (lc($1), $2);
    } else {
      return bot_says("Missing argument");
    }
  }
  
  
  if ($subcmd eq 'find') {
    bot_says($where, kw_find($dbh, $target))
  } elsif ($subcmd eq 'add') {
    bot_says($where, kw_add($dbh, $who, $target, $definition))
  } elsif ($subcmd eq 'new') {
    bot_says($where, kw_new($dbh, $who, $target, $definition))
  } elsif ($subcmd eq 'forget') {
    bot_says($where, kw_remove($dbh, $who, $target))
  } elsif ($subcmd eq 'delete') {
    bot_says($where, kw_delete_item($dbh, $target, $slot))
  } elsif ($subcmd eq 'show') {
    bot_says($where, kw_show($dbh, $target))
  } else {
    bot_says($where, "wtf?")
  }
  return
}

# non-blocking dns lookup
sub irc_botcmd_lookup {
  my ($who, $where, $arg) = @_[ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
  return unless is_where_a_channel($where) || check_if_admin($who);
  if ($arg =~ m/(([0-9]{1,3}\.){3}([0-9]{1,3}))/) {
    my $ip = $1;
    # this is from `man perlsec` so it has to be safe
    die "Can't fork: $!" unless defined(my $pid = open(KID, "-|"));
    if ($pid) {           # parent
      while (<KID>) {
	bot_says($where, $_);
      }
      close KID;
      return;
    } else {
      # this is the external process, forking. It never returns
      exec 'host', $ip or die "Can't exec host: $!";
    }
  }
  my ($type, $host) = $arg =~ /^(?:(\w+) )?(\S+)/;
  return unless $host;
  my $res = $dns->resolve(
			  event => 'dns_response',
			  host => $host,
			  type => $type,
			  context => {
				      where => $where,
				      nick  => $nick,
				     },
			 );
    $poe_kernel->yield(dns_response => $res) if $res;
  return;
}

sub irc_botcmd_lremind {
  my $where = $_[ARG1];
  my $query = $dbh->prepare("SELECT id,author,time,phrase FROM reminders WHERE chan= ? ORDER by time ASC;");
  $query->execute($where);
  my $count;
  while (my @values = $query->fetchrow_array()) {
    my $now = time();
    my $time = $values[2];
    my $nick = $values[1];
    my $string = $values[3];
    $string = $bbold . $string . $ebold;
    my $id = $values[0];
    my $eta = $time - $now;
    my $days = int($eta/(24*60*60));
    my $hours = ($eta/(60*60))%24;
    my $mins = ($eta/60)%60;
    bot_says($where, "Reminder $id for $nick: $string, happens in $days day(s), $hours hour(s) and $mins minute(s)");
    $count++
  }
  bot_says($where, "No active reminders for $where") unless $count;
}

sub irc_botcmd_math {
  my ($where, $arg) = @_[ARG1, ARG2];
  if ($arg =~ m/^\s*(-?[\d\.]+)\s*([\*\+\-\/\%])\s*(-?[\d.]+)\s*$/) {
    my $first = $1;
    my $op = $2;
    my $last = $3;
    my $result;

    if (($last == 0) && (($op eq "/") or ($op eq "%"))) {
      bot_says($where, "Illegal division by 0");
      return;
    }

    if ($op eq '+') {
      $result = $first + $last;
    }
    elsif ($op eq '-') {
      $result = $first - $last;
    }
    elsif ($op eq '*') {
      $result = $first * $last;
    }
    elsif ($op eq '/') {
      $result = $first / $last;
    }
    elsif ($op eq '%') {
      $result = $first % $last;
    }
    if ($result == 0) {
      $result = "0 ";
    }
    bot_says($where, $result);
  }
  else {
    bot_says($where, "uh?");
  }
  return
}

sub irc_botcmd_meteo {
  my ($where, $arg) = @_[ARG1, ARG2];
  if (! defined $arg) {
    bot_says($where, 'Missing location.');
    return
  } elsif ($arg =~ /^\s*$/) {
    bot_says($where, 'Missing location.');
    return
  }
  print "Asking the weatherman\n";
  bot_says($where, yahoo_meteo($arg));
  return;
}

sub irc_botcmd_mode {
  my ($who, $channel, $mode) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  return unless (check_if_admin($who));
  if (! check_if_op($channel, $botnick)) {
    bot_says($channel, "I need op");
    return
  }
  $irc->yield (mode => "$channel" => "$mode");
}

sub irc_botcmd_note {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    if ($arg =~ m/\s*([^\s]+)\s+(.+)\s*$/) {
      bot_says($where, notes_add($dbh, $nick, $1, $2))
    }
    else {
      bot_says($where, "Uh? Try note nick here goes the message")
    }
    return;
}

sub irc_botcmd_notes {
  my ($who, $where, $arg) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  if (! defined $arg) {
    bot_says($where, notes_pending($dbh, $nick));
  } elsif ($arg =~ /^\s*$/) {
    bot_says($where, notes_pending($dbh, $nick));
  } else {
    my ($subcmd, $fromwho) = split(/\s+/, $arg);
    if (($subcmd eq 'del') && (defined $fromwho)) {
      bot_says($where, notes_del($dbh, $nick, $fromwho));
      return
    } else { 
      bot_says($where, "Missing or invalid argument");
    }
  }
}

sub irc_botcmd_op {
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  return unless (check_if_op($channel, $nick) || check_if_admin($who)) ;
  my @args = "";
  if (! $what) {
    @args = ("$nick");
  } else {
    @args = split(/ +/, $what);
  }
  my $status = '+o';
  pc_status($status, $channel, $botnick, @args);
}

sub irc_botcmd_psyradio {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  if (($what eq 'off') && ($psy_chk == 1) && ($channel eq $psychan)) {
    return unless (check_if_op($channel, $nick) || check_if_admin($who));
    bot_says($channel, "Stopping psyradio broadcasting on $channel..");
    $_[KERNEL]->alarm_remove($psy_id);
    $psy_chk = 0;
    return;
  } elsif (($what eq 'on') && ($psy_chk == 0) && ($channel eq $psychan)) {
    return unless (check_if_op($channel, $nick) || check_if_admin($who));
    bot_says($channel, "Starting psyradio broadcasting on $channel..");
    $kernel->delay_set("psyradio_sentinel", 5);
    return;
  } elsif ($what eq 'status') {
    if (($psyradio) && ($psychan)) {
      if ($psy_chk) {
	bot_says($channel, "Psyradio is " . "$bbold" . "enabled at boot" . "$ebold" . " in config file on psychannel $psychan and broadcasting is currently " . "$bbold" . "on" . "$ebold" . ". To stop it tell me " . "\"$botconfig{'botprefix'}" . "psyradio off\"");
      } else {bot_says($channel, "Psyradio is " . "$bbold" . "enabled at boot" . "$ebold" . " in config file on psychannel $psychan but broadcasting is currently " . "$bbold" . "off" . "$ebold" . ". If you just started the bot, please wait a few minutes and check status again, otherwise you can manually start broadcasting in $psychan with " . "\"$botconfig{'botprefix'}" . "psyradio on\".");}
    } elsif (($psyradio) && (! $psychan)) {
      bot_says($channel, "Psyradio is " . "$bbold" . "enabled at boot" . "$ebold" . " in config file but psychannel for titles broadcasting is not set, so you cannot manually start broadcasting until you edit the configuration.");
    } elsif ((! $psyradio) && ($psychan)) {
      if ($psy_chk) {
	bot_says($channel, "Psyradio is " . "$bbold" . "not enabled at boot" . "$ebold" . " in config file; psychannel for titles broadcasting is set to $psychan: broadcasting is currently " . "$bbold" . "on" . "$ebold" . ".");
      } else {
	bot_says($channel, "Psyradio is " . "$bbold" . "not enabled at boot" . "$ebold" . " in config file; psychannel for titles broadcasting is set to $psychan but broadcasting is currently " . "$bbold" . "off" . "$ebold" . "; you can manually start it in $psychan with " . "\"$botconfig{'botprefix'}" . "psyradio on\"");}
    } elsif ((! $psyradio) && (! $psychan)) {
      bot_says($channel, "Psyradio is " . "$bbold" . "not enabled at boot" . "$ebold" . " in config file and psychannel for titles broadcasting is not set, so you must edit the config file before trying to manually start broadcasting.");
    }
  } elsif (($what eq 'last') && ($psychan) && ($channel eq $psychan) && ($psy_chk == 1)) {
    bot_says($channel, "Last and current track is " . "$bbold" .  "\"$lastsong\"" . "$ebold");
  } else {bot_says($channel, "Fail, check " . "\"$botconfig{'botprefix'}" . "psyradio status\"");}
}

sub irc_botcmd_quote {
  my ($who, $where, $what) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  my @args = split(/ +/, $what);
  my $subcmd = shift(@args);
  my $string = join (" ", @args);
  my $reply;
  if ($subcmd eq 'add' && $string =~ /.+/) {
    $reply = ircquote_add($dbh, $who, $where, $string)
  } elsif ($subcmd eq 'del' && $string =~ /.+/) {
    $reply = ircquote_del($dbh, $who, $where, $string)
  } elsif ($subcmd eq 'rand') {
    $reply = ircquote_rand($dbh, $where)
  } elsif ($subcmd eq 'last') {
    $reply = ircquote_last($dbh, $where)
  } elsif ($subcmd =~ m/([0-9]+)/) {
    $reply = ircquote_num($dbh, $1, $where)
  } elsif ($subcmd eq 'find' && $string =~ /.+/) {
    $reply = ircquote_find($dbh, $where, $string)
  } elsif ($subcmd eq 'list') {
    if (check_if_admin($who)) {
      $reply = ircquote_list($dbh);
    } else {$reply = "Only admin are permitted to list."}
  } else {
    $reply = "Command not supported"
  }
  bot_says($where, $reply);
  return
}

sub irc_botcmd_remind {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my ($who, $where, $what) = @_[ARG0..$#_];
  if ((!$what) or $what =~ m/^\s+$/) {
    bot_says($where, 'Missing argument.');
    return;
  }
  
  my $nick = parse_user($who);
  my $seconds;
  my @args = split(/ +/, $what);
  my $time = shift(@args);
  my $string = join (" ", @args);
  
  if ($what =~ m,^(.+)\s+--\s+(.+?)\s*$,) {
    $string = $1;
    my $target;
    eval { $target = str2time($2) };
    return bot_says($where, "Invalid format") unless $target;
    $seconds =  $target - time();
  } else {
    if (($string) && defined $string) {
      if (($time) && defined $time && $time =~ m/^(\d+)d(\d+)h(\d+)m$/) {
	$seconds = ($1*86400)+($2*3600)+($3*60);
      } elsif (($time) && defined $time && $time =~ m/^(\d+)h(\d+)m$/) {
	$seconds = ($1*3600)+($2*60);
      } elsif (($time) && defined $time && $time =~ m/^(\d+)m?$/) {
	$seconds = $1*60;
      } else {
	bot_says($where, 'Wrong syntax: ask me "help remind"');
	return;
      }
    }
  }
  if ($seconds <= 0) {
      bot_says($where, "This date in the past, idiot!");
      return;
  }
  my $delay = time() + $seconds;
  my $query = $dbh->prepare("INSERT INTO reminders (chan, author, time, phrase) VALUES (?, ?, ?, ?);");
  $query->execute($where, $nick, $delay, $string);
  my $select = $dbh->prepare("SELECT id FROM reminders WHERE chan = ? AND author = ? AND phrase = ?;");
  $select->execute($where, $nick, $string);
  my $id = $select->fetchrow_array();
  my $delayed = $irc->delay ( [ privmsg => $where => "$nick, it's time to: $string" ], $seconds );
  $_[KERNEL]->delay_add(reminder_del => $seconds => $id);
  bot_says($where, "reminder scheduled for " . localtime($delay));
}

sub irc_botcmd_restart {
  my ($kernel, $who, $where, $arg) = @_[KERNEL, ARG0, ARG1, ARG2];
  return unless (sanity_check($who, $where));
  $poe_kernel->signal($poe_kernel, 'POCOIRC_SHUTDOWN', 'Goodbye, cruel world');
  $kernel->delay_set(greetings_and_die => 10);
}

sub irc_botcmd_rss {
  my $mask = $_[ARG0];
  my $nick = (split /!/, $mask)[0];
  my ($where, $arg) = @_[ARG1, ARG2];
  my @args = split / +/, $arg;
  my ($action, $feed, $url) = @args;
  if ($action eq 'list') {
    if ($feed or $url) {
      return bot_says($where, "Wrong argument to list (none required)");
    } else {
      my $reply = rss_list($dbh, $where);
      bot_says($where, $reply);
      return;
    }
  }
  elsif ($action eq 'show') {
    if (! $feed) {
      return bot_says($where, "I need a feed name to show.");
    } else {
      my @replies = rss_give_latest($dbh, $feed);
      foreach my $line (@replies) {
	bot_says($where, $line);
      }
    return;
    }
  }

  unless (check_if_op($where, $nick) or check_if_admin($mask)) {
    bot_says($where, "You need to be a channel operator to manage the RSS, sorry");
    return;
  }
  if (($action eq 'add') &&
      $feed && $url) {
    my $reply = rss_add_new($dbh, $feed, $where, $url);
    bot_says($where, "$reply");
  }
  elsif (($action eq 'del') && $feed) {
    my ($reply, $purged) = rss_delete_feed($dbh, $feed, $where);
    if ($reply) {
      bot_says($where, $reply);
      if ($purged && ($feed =~ m/^\w+$/)) {
	unlink File::Spec->catfile($localdir, $feed);
      }
    } else {
      bot_says($where, "Problems deleting $feed");
    }
  }
  else {
    bot_says($where, "Usage: rss add <feedname> <url>, or rss del <feedname>");
    return;
  }
}

sub irc_botcmd_seen {
  my ($heap, $nick, $channel, $target) = @_[HEAP, ARG0..$#_];
  $nick = parse_user($nick);
  if (($target) && $target =~ m/^\s+$/) {
    return;
  } elsif (! defined $target) { 
    return;
  }
  elsif ($target) {
    $target =~ s/\s+//g;
  }
  my $botnick = $irc->nick_name;
  #  print "processing seen command\n";
  if ($seen->{l_irc($target)}) {
    my $date = localtime $seen->{l_irc($target)}->[USER_DATE];
    my $msg = $seen->{l_irc($target)}->[USER_MSG];
    if ("$target" eq "$nick") {
      $irc->yield(privmsg => $channel, "$nick: Looking for yourself, ah?");
    } elsif ($target =~ m/\Q$botnick\E/) {
      $irc->yield(privmsg => $channel, "$nick: I'm right here!");
    } elsif ($irc->is_channel_member($channel, $target)) {
      $irc->yield(privmsg => $channel,
                  "$nick: $target is here and i last saw $target at $date $msg.");
    } else {
      $irc->yield(privmsg => $channel, "$nick: I last saw $target at $date $msg");
    }
  } else {
    if ($irc->is_channel_member($channel, $target)) {
      $irc->yield(privmsg => $channel,
                  "$nick: $target is here but he didn't say a thing, AFAIK.");
    } else {
      $irc->yield(privmsg => $channel, "$nick: I haven't seen $target");
    }
  }
}

sub irc_botcmd_slap {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    my $botnick = $irc->nick_name;
    if ($arg =~ m/\Q$botnick\E/) {
      $irc->yield(ctcp => $where, "ACTION slaps $nick with her tail");
    } elsif ($arg =~ /^\s*$/) { 
      return
    } else {
      my $dest = $arg;
      $dest =~ s/\s+$//;
      $irc->yield(ctcp => $where, "ACTION slaps $dest with her tail");
    }
    return;
}

sub irc_botcmd_timebomb {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  my @args = split(/ +/, $what);
  my $target = shift(@args);
  my @colors = ('red', 'yellow', 'blue', 'brown', 'pink', 'green', 'gold', 'magenta', 'orange', 'beige', 'black', 'grey', 'lime', 'navy');
  my @wires;
  while (@wires <= 3) {
    my $lenght = scalar @colors;
    my $random = int(rand($lenght));
    my $wire = splice(@colors,$random,1);
    push @wires,$wire;
  }
  if (! check_if_op($channel, $botnick)) {
    bot_says($channel, "op me first; You know, just in case ;)");
    return
  }
  if (defined $bomb_active{$channel}) {
    bot_says($channel, "A bomb is already set.");
    return;
  } elsif (defined $alarm_active{$channel}) {
    bot_says($channel, "An alarm is still active, please try again in a few seconds.");
    return;
  }
  if ($target) {
    if ($target eq $botnick) {
      bot_says($channel, "$nick: you mad bro?!");
      return;
    } else {
      if ($irc->is_channel_member($channel, $target)) {
	bot_says($channel, "$nick slips a bomb on $target\'s panties: the display reads \"$bbold@wires$ebold\"; $target: which wire would you like to cut to defuse the bomb? You have about 20 secs left..");
	my $lenght = scalar @wires;
	my $random = int(rand($lenght));
	$defuse{$channel} = $wires[$random];
#	print "defuse = $defuse{$channel}\n";
	$bomb_active{$channel} = 1;
	my $reason = "Booom!";
	$kernel->delay_set("timebomb_start", 20, $target, $channel, $botnick, $reason);
	$alarm_active{$channel} = 1;
      }
    }
  } else {
    bot_says($channel, "\*system failure\*: Missing Target.");
    return;
  }
}

sub irc_botcmd_todo {
  my ($who, $chan, $arg) = @_[ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
  #  bot_says($chan, $irc->nick_channel_modes($chan, $nick));
  unless (($irc->is_channel_operator($chan, $nick)) or 
	  ($irc->nick_channel_modes($chan, $nick) =~ m/[aoq]/)
	  or check_if_admin($who))
    {
    bot_says($chan, "You're not a channel operator. " . todo_list($dbh, $chan));
    return
  }
   my @commands_args;
  if ($arg) {
    @commands_args = split(/\s+/, $arg);
  }
  my $task = "none";
  if (@commands_args) {
    $task = shift(@commands_args);
  }
  my $todo;
  if (@commands_args) {
    $todo = join " ", @commands_args;
  }
  if ($task eq "list") {
    bot_says($chan, todo_list($dbh, $chan));
  } 
  elsif ($task eq "add") {
    bot_says($chan, todo_add($dbh, $chan, $todo))
  }
  elsif (($task eq "del") or 
	 ($task eq "delete") or
	 ($task eq "remove") or
	 ($task eq "done")) {
    if ($todo =~ m/^([0-9]+)$/) {
      bot_says($chan, todo_remove($dbh, $chan, $1));      
    } else {
      bot_says($chan, "Give the numeric index to delete the todo")
    }
  }
  elsif ($task eq "rearrange") {
    bot_says($chan, todo_rearrange($dbh, $chan))
  }
  else {
    bot_says($chan, todo_list($dbh, $chan));
  }
  return
}

sub irc_botcmd_topic {
  my ($who, $channel, $topic) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  my $botnick = $irc->nick_name;
  if (! check_if_op($channel, $botnick)) {
    bot_says($channel, "I need op");
    return
  }
  if ((! $topic) or ($topic =~ m/^\s*$/)) {
    bot_says($channel, 'Missing argument (the actual topic to set)');
  } else {
    return unless (check_if_op($channel, $nick)) || (check_if_admin($who));
    $irc->yield (topic => "$channel" => "$topic");
  }
}

sub irc_botcmd_uptime {
  my $where = $_[ARG1];
  my $now = time;
  my $uptime = $now - $starttime;
  my $days = int($uptime/(24*60*60));
  my $hours = ($uptime/(60*60))%24;
  my $mins = ($uptime/60)%60;
  my $secs = $uptime%60;
  bot_says($where, "uptime: $days day(s), $hours hour(s), $mins minute(s) and $secs sec(s).");
}

sub irc_botcmd_urban {
  my ($where, $arg) = @_[ARG1..$#_];
  my @args = split(/ +/, $arg);
  my $subcmd = shift(@args);
  my $string = join (" ", @args);
  if (! $arg) { return }
  elsif ($arg =~ m/^\s*$/) { return } 
  elsif (($subcmd) && $subcmd eq "url" && ($string)) {
    my $baseurl = 'http://www.urbandictionary.com/define.php?term=';
    my $url = $baseurl . uri_escape($string);
    bot_says($where, $url);
  } else {
    bot_says($where, search_urban($arg));
  }
}

sub irc_botcmd_version {
  my $where = $_[ARG1];
  bot_says($where, "BirbaBot v." . "$VERSION" . ", IRC Perl Bot: " . 'https://github.com/roughnecks/BirbaBot');
  return;
}

sub irc_botcmd_voice {
  my ($who, $channel, $what) = @_[ARG0..$#_];
  my $botnick = $irc->nick_name;
  my $nick = parse_user($who);
  return unless (check_if_op($channel, $nick) || check_if_admin($who)) ;
  my @args = "";
  if (! $what) {
    @args = ("$nick");
  } else {
    @args = split(/ +/, $what);
  }
  my $status = '+v';
  pc_status($status, $channel, $botnick, @args);
}

sub irc_botcmd_whoami {
  my ($who, $channel) = @_[ARG0, ARG1];
  my $nick = parse_user($who);
  if (check_if_admin($who)) {
    bot_says($channel, "Hi $nick, i recognize you as a bot-admin.");
  } elsif (check_if_op($channel, $nick)) {
    bot_says($channel, "Hi $nick, you have operator status in $channel but i do not recognize you as a bot-admin.");
  } else {bot_says($channel, "Sorry pal, i do not recognize you.");}
}

sub irc_botcmd_wikiz {
  my ($where, $arg) = @_[ARG1, ARG2];

  # get the sitemap
  my $file = get 'http://laltromondo.dynalias.net/~iki/sitemap/index.html';
  my $prepend = 'http://laltromondo.dynalias.net/~iki';
  my @out = ();

  # split sitemap in an array and extract urls
  my @list = split ( /(<.+?>)/, $file );
  my @formatlist = grep ( /href="(\.\.)(.+?)"/, @list );

  # grep the formatted list of url searching for pattern
  if (! defined $arg) {
    bot_says($where, 'Missing Argument');
    return
  } elsif ($arg =~ /^\s*$/) {
    bot_says($where, 'Missing Argument');
    return
    } else {
      @out = grep ( /\Q$arg\E/i , @formatlist );
    }
  # looping through the output of matching urls, clean some shit and spit to channel

  my %hash;
  foreach my $item (@out) {
    $item =~ m!href="(\.\.)(.+?)"!;
    $hash{$2} = 1;
  }
  @out = keys %hash;

  if (@out) {
    foreach (@out) {
      bot_says ($where, $prepend .$_);
    }
  } else {
    bot_says ($where, 'No matches found.');
  }
}

# END irc_botcmd_ subs
######################
######################






# POE related subs
##################
##################

sub debget_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my $cwd = getcwd();
  my $path = File::Spec->catdir($cwd, 'debs');
  make_path("$path") unless (-d $path);

  my @debrels = @{$debconfig{debrels}};
  return unless @debrels;
  foreach my $rel (@debrels) {
    next unless ($rel->{rel} and $rel->{url});
    print "Saving ", $rel->{rel}, "..\n";
    # WARNING! THE CONTENT IS GZIPPED, BUT UNCOMPRESSED BY GET
    my $file = File::Spec->catfile($path, $rel->{rel});
    $ENV{PATH} = "/bin:/usr/bin"; # Minimal PATH.
    my $tmpfile = File::Temp->new();
    my @command = ('curl', '-s', '--compressed', '--connect-timeout', '10',
		   '--max-time', '10',
		   '--output', $tmpfile->filename, $rel->{url});
    print "Trying ", join(" ", @command, "\n");
    if (system(@command) == 0) {
      copy($tmpfile->filename, $file)
    } else {
      print "failed ", join(" ", @command), "\n";
    }
  }
  $kernel->delay_set("debget_sentinel", 43200 ); #updates every 12H
  print "debget executed succesfully, files saved.\n";
}

sub dns_response {
    my $res = $_[ARG0];
    my @answers = map { $_->rdatastr } $res->{response}->answer() if $res->{response};

    $irc->yield(
        'notice',
        $res->{context}->{where},
        $res->{context}->{nick} . (@answers
            ? ": @answers"
            : ': no answers for "' . $res->{host} . '"')
    );
    return;
}

sub greetings_and_die {
  $ENV{PATH} = "/bin:/usr/bin"; # Minimal PATH.
  my @command = ('perl', $0, @ARGV);
  exec @command or die "can't exec myself: $!";
}

sub ping_check {                                                         
  my ($kernel, $sender) = @_[KERNEL, SENDER];                            
  my $currentime = time();                                               
  if (($currentime - $lastpinged) > 200) {                               
    print print_timestamp(), "no ping in more than 200 secs, checking\n";
    $irc->yield( userhost => $serverconfig{nick} );                      
    $lastpinged = time();                                                
  }
  $kernel->delay_set("ping_check", 60 );
  return;
}

sub psyradio_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my $song;
  eval {$song = get('http://psyradio.com.ua/ajax/radio_new.php')};
  return warn "Connection to psyradio failed: check 'http://psyradio.com.ua/ajax/radio_new.php'" unless $song;
  $song =~ s/^\x{FEFF}//;
  if ($lastsong ne $song) {
    $lastsong = $song;
    bot_says($psychan, "$bbold" . "$song" . "$ebold");
  }
  $psy_id = $kernel->delay_set("psyradio_sentinel", 100);
  $psy_chk = 1;
  return;  
}

sub reminder_del {
  my ($kernel, $sender, $id) = @_[KERNEL, SENDER, ARG0];
  my $del_query = $dbh->prepare("DELETE from reminders WHERE id = ?;");
  $del_query->execute($id);
  print "reminder deleted\n";
}

sub reminder_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my $query = $dbh->prepare("SELECT id,chan,author,time,phrase FROM reminders;");
  $query->execute();
  while (my @values = $query->fetchrow_array()) {
    my $now = time();
    my $time = $values[3];
    my $where = $values[1];
    my $nick = $values[2];
    my $string = $values[4];
    my $id = $values[0];
    if ($time > $now) {
      my $new_delay = $time - $now;
      my $delayed = $irc->delay ( [ privmsg => $where => "$nick, it's time to: $string" ], $new_delay );
      $_[KERNEL]->delay_add(reminder_del => $new_delay => $id);
    } else {
      bot_says($where, "$nick: reminder expired before execution; was: $string");
      my $del_query = $dbh->prepare("DELETE from reminders WHERE id = ?;");
      $del_query->execute($id);
    }
  }
}

sub rss_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  print print_timestamp(), "Starting fetching RSS...\n";
  my $feeds = rss_get_my_feeds($dbh, $localdir);
  foreach my $channel (keys %$feeds) {
    foreach my $feed (@{$feeds->{$channel}}) {
      $irc->yield( privmsg => $channel => $feed);
    }
  }
  print print_timestamp(), "done!\n";
  # set the next loop
  $kernel->delay_set("rss_sentinel", $botconfig{rsspolltime})
}

sub save {
    my $kernel = $_[KERNEL];
    warn "storing\n";
    store($seen, DATA_FILE) or die "Can't save state";
    $kernel->delay_set('save', SAVE_INTERVAL);
}

sub tail_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my $what = $botconfig{tail};
  my @ignored = @{$botconfig{'ignored_lines'}};
  return unless (%$what);
  foreach my $file (keys %{$what}) {
    my $channel = $what->{$file};
    my @things_to_say = file_tail($file);
    while (@things_to_say) {
      my $thing = shift @things_to_say;
      next if ($thing =~ m/^\s*$/);
      # see if the line should be ignored
      my $in_ignore;
      foreach my $ignored (@ignored) {
	if ((index $thing, $ignored) >= 0) {
	  $in_ignore++;
	}
      }
      bot_says($channel, $thing) unless $in_ignore;
    }
  }
  $kernel->delay_set("tail_sentinel", 60)
}


sub timebomb_start {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my ($target, $channel, $botnick, $reason) = @_[ARG0..$#_];
  if (defined $bomb_active{$channel}) {
    pc_kick($botnick, $target, $channel, $botnick, $reason);
    undef $bomb_active{$channel};
    undef $defuse{$channel};
    undef $alarm_active{$channel};
    return;
  } else { return undef $alarm_active{$channel}; }
}

# END POE related subs
######################
######################






# Other NON-POE subs
####################
####################

## keyword stuff
sub _kw_manage_request {
  my ($what, $nick, $where, $channel) = @_;
  print_timestamp(join ":", @_);
  if ($what =~ /^(\Q$botconfig{'kw_prefix'}\E)(.+)\s+>{1,2}\s*$/) {
    bot_says($channel, "Please specify a valid nickname.");
    return;
  } elsif ( my ($kw) = $what =~ /^(\Q$botconfig{'kw_prefix'}\E)(.+)\s+>{1}\s+([\S]+)\s*$/ ) {
    my $target = $3;
    my $fact = $2;
    my $query = (kw_query($dbh, $nick, lc($fact)));
    if ($irc->is_channel_member($channel, $target)) {
      if ((! $query) or ( $query =~ m/^ACTION\s(.+)$/ )) {
	bot_says($channel, "$nick, that fact does not exist or it can't be told to $target; try \"kw show $fact\" to see its content.");
	return;
      } else {
	bot_says($channel, "$target: "."$query");
      } 
    }
  } elsif ( my ($kw2) = $what =~ /^(\Q$botconfig{'kw_prefix'}\E)(.+)\s+>{2}\s+([\S]+)\s*$/ ) {
    my $target = $3;
    my $fact = $2;
    my $query = (kw_query($dbh, $nick, lc($fact)));
    if ($irc->is_channel_member($channel, $target)) {
      if ((! $query ) or ($query =~ m/^ACTION\s(.+)$/)) {
	bot_says($channel, "$nick, that fact does not exist or it can't be told to $target; try \"kw show $fact\" to see its content.");
	return;
      } else {
	$irc->yield(privmsg => $target, "$fact is $query");
	$irc->yield(privmsg => $nick, "Told $target about $fact");
      }
    } else {
      bot_says($channel, "Dunno about $target");
      return;
    }
  } elsif ($what =~ /^(\Q$botconfig{'kw_prefix'}\E)(.+)\s*$/ ) {
    my $kw = $2;
    my $query = (kw_query($dbh, $nick, lc($kw)));
    if (($query) && ($query =~ m/^ACTION\s(.+)$/)) {
      $irc->yield(ctcp => $where, "ACTION $1");
      return;
    } elsif ($query) {
      bot_says($channel, $query);
      return;
    }
    return;
  }
}


sub add_nick {
  my ($nick, $msg) = @_;
  $seen->{l_irc($nick)} = [time, $msg];
}

sub bot_says {
  my ($where, $what) = @_;
  return unless ($where and (defined $what));

  # Let's use HTML::Entities
  $what = decode_entities($what);
  
  #  print print_timestamp(), "I'm gonna say $what on $where\n";
  if (length($what) < 400) {
    $irc->yield(privmsg => $where => $what);
  } else {
    my @output = ("");
    my @tokens = split (/\s+/, $what);
    if ($tokens[0] =~ m/^(\s+)(.+$)/) {
      $tokens[0] = $2;
    }
    while (@tokens) {
      my $string = shift(@tokens);
      my $len = length($string);
      my $oldstringleng = length($output[$#output]);
      if (($len + $oldstringleng) < 400) {
	$output[$#output] .= " $string";
      } else {
	push @output, $string;
	if ($output[0] =~ m/^(\s+)(.+$)/) {
	  $output[0] = $2;
	}
      }
    }
    foreach my $reply (@output) {
      $irc->yield(privmsg => $where => $reply);
    }
  }
  return
}

sub chan_msg_parser {
  my ($what, $nick, $channel, $botnick, $where) = @_;
  
  # this will push in @longurls
  $urifinder->find(\$what);
  while (@longurls) {
    my $url = shift @longurls;
  # print "Found $url\n";
    if ($url =~ m/^https?:\/\/(www\.)?youtube/) {
      bot_says($channel, get_youtube_title($url));
    }
    if ($url =~ m/youtu\.be\/(.+)$/) {
      my $newurl = "http://www.youtube.com/watch?v="."$1";
      bot_says($channel, get_youtube_title($newurl));
    }	
    
    next if (length($url) <= 65);
    next unless ($url =~ m/^(f|ht)tp/);
    my $reply = $nick . "'s url: " . make_tiny_url($url);
    bot_says($channel, $reply);
  }
  
  # keywords
  if ($what =~ /^(\Q$botconfig{'kw_prefix'}\E)(.+)\s*$/) {
    return _kw_manage_request($what, $nick, $where, $channel)
  }
  
  # Here we parse other channel messages' content
  if ($what =~ /((AH){2,})/) {
    bot_says($channel, "AHAHAHAHAHAH!");
    return;
  }

  # karma
  if ($what =~ /^\s*([^\s]+)(\+\+|--)(\s+#.+)?\s*$/) {
    my $karmanick = $1;
    my $karmaaction = $2;
    if ($karmanick eq $nick) {
      bot_says($channel, "You're cheating, moron!");
      return;
    } 
    elsif (! $irc->is_channel_member($channel, $karmanick)) {
      print "$karmanick is not here, skipping\n";
      return;
    }
    elsif ($karmanick eq $botnick) {
      if ($karmaaction eq '++') {
	bot_says($channel, "meeow")
      } else {
	bot_says($channel, "fhhhhrrrrruuuuuuuuuuu")
      }
      print print_timestamp(),
	karma_manage($dbh, $karmanick, $karmaaction), "\n";
      return;
    }
    else {
      bot_says($channel, karma_manage($dbh, $karmanick, $karmaaction));
      return;
    }
  } 
}

sub check_if_admin {
  my $mask = shift;
  return 0 unless $mask;
  foreach my $regexp (@adminregexps) {
    if ($mask =~ m/$regexp/) {
      return 1
    }
  }
  return 0;
}

sub check_if_fucker {
  my ($object, $nick, $place, $command, $args) = @_;
  #  print "Authorization for $nick";
  foreach my $pattern (@fuckers) {
    if ($nick =~ m/\Q$pattern\E/i) {
      # print "$nick match $pattern?";
      return 0, [];
    }
  }
  return 1;
}

sub check_if_op {
  my ($chan, $nick) = @_;
  return 0 unless $nick;
  if (($irc->is_channel_operator($chan, $nick)) or 
      ($irc->nick_channel_modes($chan, $nick) =~ m/[aoq]/)) {
    return 1;
  }
  else {
    return 0;
  }
}

sub is_where_a_channel {
  my $where = shift;
  if ($where =~ m/^#/) {
    return 1
  } else {
    return 0
  }
}

sub pc_ban {
  my ($mode, $channel, $botnick, @args) = @_;
  if (! check_if_op($channel, $botnick)) {
    bot_says($channel, "I need op");
    return
  }
  foreach (@args) {
    next if ("$_" eq "$botnick");
    if ($irc->is_channel_member($channel, $_)) {
      my $whois = $irc->nick_info($_);
      my $host = $$whois{'Host'};
      $irc->yield (mode => "$channel" => "$mode" => "\*!\*\@$host");
    }
  } 
}

sub pc_kick {
  my ($nick, $target, $channel, $botnick, $reason) = @_;
  return if ("$target" eq "$botnick");
  if (! check_if_op($channel, $botnick)) {
    bot_says($channel, "I need op");
    return
  }
  if ($irc->is_channel_member($channel, $target)) {
    if ($reason) {
      my $message = $reason.' ('.$nick.')';
      $irc->yield (kick => "$channel" => "$target" => "$message");
    } else {
      my $message = 'no reason given'.' ('.$nick.')';
      $irc->yield (kick => "$channel" => "$target" => "$message");
    }
  }
}

sub pc_status {
  my ($status, $channel, $botnick, @args) = @_;
  if (! check_if_op($channel, $botnick)) {
    bot_says($channel, "I need op");
    return
  }
  foreach (@args) {
    next if ("$_" eq "$botnick");
    if ($irc->is_channel_member($channel, $_)) {
      $irc->yield (mode => "$channel" => "$status" => "$_");
    }
  } 
}

sub print_timestamp {
    my $time = localtime();
    return "[$time] "
}

sub process_admin_list {
  my @masks = @_;
  my @regexp;
  foreach my $mask (@masks) {
    # first, we check nick, username, host. The *!*@* form is required
    if ($mask =~ m/(.+)!(.+)@(.+)/) {
      $mask =~ s/(\W)/\\$1/g;	# escape everything which is not a \w
      $mask =~ s/\\\*/.*?/g;	# unescape the *
      push @regexp, qr/^$mask$/;
    } else {
      print "Invalid mask $mask, must be in *!*@* form"
    }
  }
  print Dumper(\@regexp);
  return @regexp;
}

sub sanity_check {
  my ($who,$where) = @_;
  return unless $who;
  return unless $where;
  unless (check_if_admin($who)) {
    bot_says($where, "Who the hell are you?");
    return undef;
  };
  if ((-e basename($0)) &&
      (-d ".git") &&
      (-d "BirbaBot") &&
      (check_if_admin($who))) {
    return 1;
  } else {
    bot_says($where, "I can't find myself");
    return undef;
  }
}

## END NON-POE subs
###################
###################

$dbh->disconnect;
exit;


## FIN
