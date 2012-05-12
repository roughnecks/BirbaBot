#!/usr/bin/perl
# -*- mode: cperl -*-

# No copyright
# Written by Marco Pessotto a.k.a. MelmothX

# This code is free software; you may redistribute it
# and/or modify it under the same terms as Perl itself.

use strict;
use warnings;

use LWP::Simple;
use File::Spec;
use File::Path qw(make_path);
use Data::Dumper;
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
			  google_translate
			  query_meteo
			  search_imdb
			  search_bash
			  search_urban
			  get_youtube_title
			);
use BirbaBot::Infos qw(kw_add kw_new kw_query kw_remove kw_list kw_delete_item karma_manage);
use BirbaBot::Todo  qw(todo_add todo_remove todo_list todo_rearrange);
use BirbaBot::Notes qw(notes_add notes_give notes_pending notes_del);
use BirbaBot::Shorten qw(make_tiny_url);
use BirbaBot::Quotes qw(ircquote_add 
		    ircquote_del 
		    ircquote_rand 
		    ircquote_last 
		    ircquote_find
		    ircquote_num);
use BirbaBot::Tail qw(file_tail);

use URI::Find;
use URI::Escape;

use HTML::Entities;

use POE;
use POE::Component::Client::DNS;
use POE::Component::IRC::Common qw(parse_user l_irc);
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::BotCommand;
use Storable;
use YAML::Any qw/LoadFile/;

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

# before starting, create a pid file

open (my $fh, ">", "birba.pid");
print $fh $$;
close $fh;
undef $fh;

# initialize the db

my $reconnect_delay = 300;

my %serverconfig = (
		    'nick' => 'Birba',
		    'ircname' => "Birba the Bot",
		    'username' => 'birbabot',
		    'server' => "localhost",
		    'port' => 7000,
		    'usessl' => 1,
		   );

my %botconfig = (
		 'channels' => ["#lamerbot"],
		 'botprefix' => "@",
		 'rsspolltime' => 600, # default to 10 minutes
		 'dbname' => "bot.db",
		 'admins' => [ 'nobody!nobody@nowhere' ],
		 'fuckers' => [ 'fucker1',' fucker2'],
		 'nspassword' => 'nopass',
		 'tail' => {},
		 'ignored_lines' => [],
		);

# initialize the local storage
my $localdir = File::Spec->catdir('data','rss');
make_path($localdir) unless (-d $localdir);

my $config_file = $ARGV[0];
my $debug = $ARGV[1];

show_help() unless $config_file;

### configuration checking 
my ($botconf, $serverconf) = LoadFile($config_file);
override_defaults(\%serverconfig, $serverconf);
override_defaults(\%botconfig, $botconf);

print "Bot options: ", Dumper(\%botconfig),
  "Server options: ", Dumper(\%serverconfig);

my $dbname = $botconfig{'dbname'};

my @channels = @{$botconfig{'channels'}};

# build the regexp of the admins
my @adminregexps = process_admin_list(@{$botconfig{'admins'}});

my @fuckers = @{$botconfig{'fuckers'}};

# when we start, we check if we have all the tables.  By no means this
# guarantees that the tables are correct. Devs, I'm looking at you
create_bot_db($dbname) or die "Errors while updating db tables";

# be sure that the feeds are in the channels we join
rss_clean_unused_feeds($dbname, \@channels);

my $starttime = time;

### starting POE stuff

my $irc = POE::Component::IRC::State->spawn(%serverconfig) 
  or die "WTF? $!\n";

my $dns = POE::Component::Client::DNS->spawn();

POE::Session->create(
    package_states => [
        main => [ qw(_start
		     _default
		     irc_001 
		     irc_notice
		     irc_disconnected
		     irc_error
		     irc_socketerr
		     irc_ping
		     irc_kick
		     irc_botcmd_free
		     irc_botcmd_uptime
		     irc_botcmd_sitedown
		     irc_botcmd_wikiz
		     irc_botcmd_remind
		     irc_botcmd_version
		     irc_botcmd_choose
		     irc_botcmd_bash
		     irc_botcmd_urban
		     irc_botcmd_karma
		     irc_botcmd_math
		     irc_botcmd_seen
		     irc_botcmd_note
		     irc_botcmd_notes
		     irc_botcmd_todo
		     irc_botcmd_done
		     irc_botcmd_kw
		     irc_botcmd_slap
		     irc_botcmd_geoip
		     irc_botcmd_lookup
		     irc_botcmd_rss
		     irc_botcmd_g
		     irc_botcmd_gi
		     irc_botcmd_gv
		     irc_botcmd_x
		     irc_botcmd_imdb
		     irc_botcmd_quote
		     irc_botcmd_meteo
		     irc_public
                    irc_join
                    irc_part
                    irc_quit
		    save
                    irc_ctcp_action
		     rss_sentinel
		     tail_sentinel
		     dns_response) ],
    ],
);

$poe_kernel->run();

## just copy and pasted, ok?

sub _start {
    my ($kernel) = $_[KERNEL];
    $irc->plugin_add('BotCommand', 
		     POE::Component::IRC::Plugin::BotCommand->new(
								  Commands => {
            slap   => 'Takes one argument: a nickname to slap.',
            lookup => 'Takes two arguments: a record type like MX, AAAA (optional), and a host.',
	    geoip => 'Takes one argument: an ip or a hostname to lookup.',
	    rss => 'Manage RSS subscriptions: RSS [ add | del ] <name> <url> - RSS show [ name ] - RSS list [ #channel ]',
            g => 'Do a google search: Takes one or more arguments as search values.',
            gi => 'Do a search on google images.',
            gv => 'Do a search on google videos.',
            bash => 'Get a random quote from bash.org - Optionally accepts one number as argument: bash <number>',
            urban => 'Get definitions from the urban dictionary | "urban url <word>" asks for the url',
            karma => 'Get the karma of a user',
            math => 'Do simple math (* / % - +). Example: math 3 * 3',
            seen => 'Search for a user: seen <nick>',
            note => 'Send a note to a user: note <nick> <message>',
	    notes => 'Without arguments lists pending notes by current user | "notes del <nickname>" Deletes all pending notes from the current user to <nickname>',
            todo => 'add something to the channel TODO; todo [ add "foo" | rearrange | done #id ] - done < #id > ',
            done => 'delete something to the channel TODO; done #id ',
	    remind => 'Store an alarm for the current user, delayed by "x minutes" or by "xhxm hours and minutes" | remind [ <x> | <xhxm> ] <message> , assuming "x" is a number',
	    wikiz => 'Performs a search on "laltrowiki" and retrieves urls matching given argument | wikiz <arg>',
            kw => 'Manage the keywords: kw foo is bar; kw foo is also bar2/3; kw forget foo; kw delete foo 2/3; kw => gives you the facts list',
            x => 'Translate some text from lang to lang (where language is a two digit country code), for example: "x en it this is a test".',
	    meteo => 'Query the weather for location',							       
            imdb => 'Query the Internet Movie Database (If you want to specify a year, put it at the end). Alternatively, takes one argument, an id or link, to fetch more data.',
	    quote => 'Manage the quotes: quote [ add <text> | del <number> | <number> | rand | last | find <argument> ]',
	    choose => 'Do a random guess | Takes 2 or more arguments: choose <choice1> <choice2> <choice#n>',
	    version => 'Show from which git branch we are running the bot. Do not use without git',
            sitedown => 'Check whether a website is up or down | sitedown <domain>',									       
	    uptime => 'Bot\'s uptime',
	    free => 'Show system memory usage',
		    },
            In_channels => 1,
	    Auth_sub => \&check_if_fucker,
	    Ignore_unauthorized => 1,
 	    In_private => 1,
            Addressed => 0,
            Prefix => $botconfig{'botprefix'},
            Eat => 1,
            Ignore_unknown => 1,
								  
								 ));
 
    $irc->yield( register => 'all' );
    $irc->yield( connect => { } );
    $kernel->delay_set('save', SAVE_INTERVAL);
    return;
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
  my $result = query_meteo($arg);
  $result =~ s/\;\s*$/./;
  bot_says($where, $result);
  return;
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
    my @tokens = split (/ +/, $what);
    while (@tokens) {
      my $string = shift(@tokens);
      my $len = length($string);
      my $oldstringleng = length($output[$#output]);
      if (($len + $oldstringleng) < 400) {
	$output[$#output] .= " $string";
      } else {
	push @output, $string;
      }
    }
    foreach my $reply (@output) {
      $irc->yield(privmsg => $where => $reply);
    }
  }
  return
}
  
sub irc_botcmd_karma {
  my ($where, $arg) = @_[ARG1, ARG2];
  $arg =~ s/\s*//g;
  if ($arg) {
    bot_says($where, karma_manage($dbname, $arg));
    return;
  } else {
    bot_says($where, karma_manage($dbname));
  }
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



sub irc_botcmd_rss {
  my $mask = $_[ARG0];
  my $nick = (split /!/, $mask)[0];
  my ($where, $arg) = @_[ARG1, ARG2];
  my @args = split / +/, $arg;
  my ($action, $feed, $url) = @args;
  if ($action eq 'list') {
    my $reply = rss_list($dbname, $where);
    bot_says($where, $reply);
    return;
  }
  elsif ($action eq 'show') {
    my @replies = rss_give_latest($dbname, $feed);
    foreach my $line (@replies) {
      bot_says($where, $line);
    }
    return;
  }

  unless (check_if_op($where, $nick) or check_if_admin($mask)) {
    bot_says($where, "You need to be a channel operator to manage the RSS, sorry");
    return;
  }
  if (($action eq 'add') &&
      $feed && $url) {
    my $reply = rss_add_new($dbname, $feed, $where, $url);
    bot_says($where, "$reply");
  }
  elsif (($action eq 'del') && $feed) {
    my ($reply, $purged) = rss_delete_feed($dbname, $feed, $where);
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

sub irc_botcmd_slap {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    my $botnick = $irc->nick_name;
    if ($arg =~ m/\Q$botnick\E/) {
      $irc->yield(ctcp => $where, "ACTION slaps $nick with her tail");
    } elsif ($arg =~ /^\s*$/) { 
      return
    } else {
      $irc->yield(ctcp => $where, "ACTION slaps $arg with her tail");
    }
    return;
}

sub irc_botcmd_note {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    if ($arg =~ m/\s*([^\s]+)\s+(.+)\s*$/) {
      bot_says($where, notes_add($dbname, $nick, $1, $2))
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
    bot_says($where, notes_pending($dbname, $nick));
  } elsif ($arg =~ /^\s*$/) {
    bot_says($where, notes_pending($dbname, $nick));
  } else {
    my @array = split(" ", $arg);
    my $subcmd = shift @array;
    if (($subcmd eq 'del') && ($array[0]) && ($array[0] =~ m/^\s*\w+\s*$/)) {
      bot_says($where, notes_del($dbname, $nick, $array[0]));
      return
    } else { 
      bot_says($where, "Missing or invalid argument");
    }
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

sub irc_botcmd_gi {
  my ($where, $arg) = @_[ARG1, ARG2];
  return unless is_where_a_channel($where);
  if (($arg) && $arg =~ /^\s*$/) {
    return
  } else { 
    bot_says($where, search_google($arg, "images"));
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

sub irc_botcmd_x {
  my ($where, $arg) = @_[ARG1, ARG2];
  if ($arg =~ m/^\s*([a-z]{2,3})\s+([a-z]{2,3})\s+(.*)\s*$/) {
    my $result = google_translate($3, $1, $2);
    $result =~ s/^\s+//;
    bot_says($where, $result);
  } else {
    bot_says($where, "Example: x hr it govno");
  }
}

sub irc_botcmd_kw {
  my ($who, $where, $arg) = @_[ARG0, ARG1, ARG2];
  print print_timestamp(), "$who, $where, $arg\n";
  if ($arg =~ m/^\s*([^\s]+)\s+is also\s+(.+?)\s*$/)  {
    my $what = $2;
    if ($what =~ /^\s*$/) {
      bot_says($where, 'Missing argument.');
      return
    } 
    bot_says($where, kw_add($dbname, $who, lc($1), $2));
  } elsif ($arg =~ m/^\s*([^\s]+)\s+is\s+(.+?)\s*$/)  {
    my $what = $2;
    if ($what =~ /^\s*$/) {
      bot_says($where, 'Missing argument.');
      return
    } 
    bot_says($where, kw_new($dbname, $who, lc($1), $2));
  } elsif ($arg =~ m/^\s*forget\s*([^\s]+)\s*$/) {
    my $key = lc($1);
    if (check_if_admin($who)) {
      bot_says($where, kw_remove($dbname, $who, $key));
      return;
    } 
    bot_says($where, "You're not a bot admin, sorry, I can't do that");
    return;
  } elsif ($arg =~ m/^\s*delete\s*([^\s]+)\s+([23])\s*$/) {
    bot_says($where, kw_delete_item($dbname, lc($1), $2));
  } elsif (! defined $arg) {
    bot_says($where, kw_list($dbname));
  } else {
    bot_says($where, 'Wrong syntax');
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


sub irc_botcmd_geoip {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    return unless is_where_a_channel($where);
    $irc->yield(privmsg => $where => BirbaBot::Geo::geo_by_name_or_ip($arg));
    return;
}

sub irc_botcmd_done {
  my ($who, $chan, $arg) = @_[ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
  #  bot_says($chan, $irc->nick_channel_modes($chan, $nick));
  unless (check_if_op($chan, $nick) or check_if_admin($who)) {
    bot_says($chan, "You're not a channel operator. " . todo_list($dbname, $chan));
    return
  }
  if ($arg =~ m/^([0-9]+)$/) {
    bot_says($chan, todo_remove($dbname, $chan, $1));      
  } else {
    bot_says($chan, "Give the numeric index to delete the todo")
  }
  return;
}

sub irc_botcmd_todo {
  my ($who, $chan, $arg) = @_[ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
#  bot_says($chan, $irc->nick_channel_modes($chan, $nick));
  unless (($irc->is_channel_operator($chan, $nick)) or 
	  ($irc->nick_channel_modes($chan, $nick) =~ m/[aoq]/)
	  or check_if_admin($who))
    {
    bot_says($chan, "You're not a channel operator. " . todo_list($dbname, $chan));
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
    bot_says($chan, todo_list($dbname, $chan));
  } 
  elsif ($task eq "add") {
    bot_says($chan, todo_add($dbname, $chan, $todo))
  }
  elsif (($task eq "del") or 
	 ($task eq "delete") or
	 ($task eq "remove") or
	 ($task eq "done")) {
    if ($todo =~ m/^([0-9]+)$/) {
      bot_says($chan, todo_remove($dbname, $chan, $1));      
    } else {
      bot_says($chan, "Give the numeric index to delete the todo")
    }
  }
  elsif ($task eq "rearrange") {
    bot_says($chan, todo_rearrange($dbname, $chan))
  }
  else {
    bot_says($chan, todo_list($dbname, $chan));
  }
  return
}


# non-blocking dns lookup
sub irc_botcmd_lookup {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    return unless is_where_a_channel($where);
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

sub irc_disconnected {
  print print_timestamp(), "Reconnecting in $reconnect_delay seconds\n";
  # we better sleep here, so we don't spam events which are not going to happen
  sleep $reconnect_delay;
  $irc->yield( connect => { });
}

sub irc_error {
  print print_timestamp(), "Reconnecting in $reconnect_delay seconds\n";
  # we better sleep here, so we don't spam events which are not going to happen
  sleep $reconnect_delay;
  $irc->yield( connect => { });
}

sub irc_socketerr {
  print print_timestamp(), "Reconnecting in $reconnect_delay seconds\n";
  # we better sleep here, so we don't spam events which are not going to happen
  sleep $reconnect_delay;
  $irc->yield( connect => { });
}

sub irc_001 {
    my ($kernel, $sender) = @_[KERNEL, SENDER];

    # Since this is an irc_* event, we can get the component's object by
    # accessing the heap of the sender. Then we register and connect to the
    # specified server.
    my $irc = $sender->get_heap();

    print print_timestamp(), "Connected to ", $irc->server_name(), "\n";

    # we join our channels waiting a few secs
    foreach (@channels) {
      $irc->delay( [ join => $_ ], 4 ); 
    }

    # here we register the rss_sentinel
    $kernel->delay_set("tail_sentinel", 20);  # first run after 20 seconds
    $kernel->delay_set("rss_sentinel", 40);  # first run after 40 seconds
    $lastpinged = time();
    return;
}

sub irc_notice {
  my ($who, $text) = @_[ARG0, ARG2];
  my $nick = parse_user($who);
  print "Notice from $who: $text", "\n";
  if ( ($nick eq 'NickServ' ) && ( $text =~ m/^This\snickname\sis\sregistered.+$/) ) {
    my $passwd = $botconfig{'nspassword'};
    $irc->yield( privmsg => "$nick", "IDENTIFY $passwd");
  }
}

sub irc_ping {
  print "Ping!\n";
  $lastpinged = time();
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

sub save {
    my $kernel = $_[KERNEL];
    warn "storing\n";
    store($seen, DATA_FILE) or die "Can't save state";
    $kernel->delay_set('save', SAVE_INTERVAL);
}

sub irc_ctcp_action {
    my $nick = parse_user($_[ARG0]);
    my $chan = $_[ARG1]->[0];
    my $text = $_[ARG2];

    add_nick($nick, "on $chan doing: * $nick $text");
}

sub irc_join {
    my $nick = parse_user($_[ARG0]);
    my $chan = $_[ARG1];
    my @notes = notes_give($dbname, $nick);
    add_nick($nick, "joining $chan");
    while (@notes) {
      bot_says($nick, shift(@notes));
    }
}

sub irc_part {
    my $nick = parse_user($_[ARG0]);
    my $chan = $_[ARG1];
    my $text = $_[ARG2];

    my $msg = 'parting $chan';
    $msg .= " with message '$text'" if defined $text;

    add_nick($nick, $msg);
}

sub irc_quit {
  my $nick = parse_user($_[ARG0]);
  my $text = $_[ARG1];

  my $msg = 'quitting';
  $msg .= " with message '$text'" if defined $text;

  add_nick($nick, $msg);
}



sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];
#    print print_timestamp(), "$nick said $what in $channel\n";
    add_nick($nick, "on $channel saying: $what");

    my ($auth, $spiterror) = check_if_fucker($sender, $who, $where, $what);
    return unless $auth;

    if ( my ($kw) = $what =~ /^([^\s]+)\?\s*$/ ) {
      bot_says($channel, kw_query($dbname, lc($1)));
      return;
    }
    elsif ($what =~ /((AH){2,})/) {
      bot_says($channel, "AHAHAHAHAHAH!");
      return;
    }
    elsif ($what =~ /^\s*([^\s]+)(\+\+|--)\s*$/) {
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
      else {
	bot_says($channel, karma_manage($dbname, $karmanick, $karmaaction));
	return;
      }
    }
    # this will push in @longurls
    $urifinder->find(\$what);
    while (@longurls) {
      my $url = shift @longurls;
      print "Found $url\n";
      if ($url =~ m/youtube/) {
	bot_says($channel, get_youtube_title($url));
      };

      next if (length($url) <= 60);
      my $reply = $nick . "'s url: " . make_tiny_url($url);
      bot_says($channel, $reply);
      return;
    }
    
#     elsif (($what =~ /\?$/) and (int(rand(6)) == 1)) {
#       bot_says($channel, "RTFM!");
#     }
#    if ($what eq "hi") {
#      if (check_if_admin($who)) {
#	bot_says($where, "Hello my master");
#      } else {
#	bot_says($where, "And who the hell are you?");
#      }
#    }
    return;
}

sub add_nick {
  my ($nick, $msg) = @_;
  $seen->{l_irc($nick)} = [time, $msg];
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
  print "processing seen command\n";
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

sub irc_botcmd_quote {
  my ($who, $where, $what) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  my @args = split(/ +/, $what);
  my $subcmd = shift(@args);
  my $string = join (" ", @args);
  my $reply;
  if ($subcmd eq 'add' && $string =~ /.+/) {
    $reply = ircquote_add($dbname, $who, $where, $string)
  } elsif ($subcmd eq 'del' && $string =~ /.+/) {
    $reply = ircquote_del($dbname, $who, $where, $string)
  } elsif ($subcmd eq 'rand') {
    $reply = ircquote_rand($dbname, $where)
  } elsif ($subcmd eq 'last') {
    $reply = ircquote_last($dbname, $where)
  } elsif ($subcmd =~ m/([0-9]+)/) {
    $reply = ircquote_num($dbname, $1, $where)
  } elsif ($subcmd eq 'find' && $string =~ /.+/) {
    $reply = ircquote_find($dbname, $where, $string)
  } else {
    $reply = "command not supported"
  }
  bot_says($where, $reply);
  return
}

sub rss_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  my $currentime = time();
  if (($currentime - $lastpinged) > 200) {
    print print_timestamp(), "no ping in more then 200 secs, checking\n";
    $irc->yield( userhost => $serverconfig{nick} );
    $kernel->delay_set("rss_sentinel", $botconfig{rsspolltime});
    return
  }
  print print_timestamp(), "Starting fetching RSS...\n";
  my $feeds = rss_get_my_feeds($dbname, $localdir);
  foreach my $channel (keys %$feeds) {
    foreach my $feed (@{$feeds->{$channel}}) {
      $irc->yield( privmsg => $channel => $feed);
    }
  }
  print print_timestamp(), "done!\n";
  # set the next loop
  $kernel->delay_set("rss_sentinel", $botconfig{rsspolltime})
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

# We registered for all events, this will produce some debug info.
sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    my @output = ( "$event: " );

    for my $arg (@$args) {
        if ( ref $arg eq 'ARRAY' ) {
            push( @output, '[' . join(', ', @$arg ) . ']' );
        }
        else {
            push ( @output, "'$arg'" );
        }
    }
    print print_timestamp(), join ' ', @output, "\n";
    return 0;
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

sub check_if_admin {
  my $mask = shift;
  foreach my $regexp (@adminregexps) {
    if ($mask =~ m/$regexp/) {
      return 1
    }
  }
  return 0;
}

sub check_if_op {
  my ($chan, $nick) = @_;
  if (($irc->is_channel_operator($chan, $nick)) or 
      ($irc->nick_channel_modes($chan, $nick) =~ m/[aoq]/)) {
    return 1;
  }
  else {
    return 0;
  }
}

sub check_if_fucker {
  my ($object, $nick, $place, $command, $args) = @_;
#  print "Authorization for $nick";
  foreach my $pattern (@fuckers) {
    if ($nick =~ m/\Q$pattern\E/i) {
#      print "$nick match $pattern?";
      return 0, [];
    }
  }
  return 1;
}

sub is_where_a_channel {
  my $where = shift;
  if ($where =~ m/^#/) {
    return 1
  } else {
    return 0
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
  
sub irc_botcmd_version {
  my $where = $_[ARG1];
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
}

sub irc_botcmd_remind {
  my ($who, $where, $what) = @_[ARG0..$#_];
  my $nick = parse_user($who);
  my $seconds;
  my @args = split(/ +/, $what);
  my $time = shift(@args);
  my $string = join (" ", @args);
  if (($string) && defined $string) {
    if (($time) && defined $time && $time =~ m/^(\d+)h(\d+)m$/) {
      $seconds = ($1*3600)+($2*60);
    } elsif (($time) && defined $time && $time =~ m/^(\d+)$/) {
      $seconds = $1*60;
    } else {
      bot_says($where, 'Wrong syntax: ask me "help remind" <= This is for the lazy one :)');
      return
    }
  } else {
    bot_says($where, 'Missing argument');
    return
  }
  $irc->delay ( [ privmsg => $where => "$nick, it's time to: $string" ], $seconds );
  bot_says($where, 'Reminder added.');
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
      @out = grep ( /\Q$arg\E/ , @formatlist );
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

sub irc_botcmd_sitedown {
  my ($where, $what) = @_[ARG1, ARG2];
  return unless is_where_a_channel($where);
  return unless $what =~ m/^\s*(\w.+\.)+[a-z]{2,3}$/;
  my $prepend = 'http://www.downforeveryoneorjustme.com/';
  my $query = $prepend . $what;
  print "Asking downforeveryoneorjustme for $query\n";
  my $file = get "$query";
  if ( $file =~ m|<title>(.+)</title>|s ) {
    my $result = $1;
    $result =~ s/->.*$//;
    bot_says($where, $result);
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


sub irc_botcmd_free {
  my $where = $_[ARG1];
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


exit;

