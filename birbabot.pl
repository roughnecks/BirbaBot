#!/usr/bin/perl
# -*- mode: cperl -*-

# No copyright
# Written by Marco Pessotto a.k.a. MelmothX

# This code is free software; you may redistribute it
# and/or modify it under the same terms as Perl itself.

use strict;
use warnings;

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
			  search_imdb
			);
use BirbaBot::Infos qw(kw_add kw_new kw_query kw_remove);
use BirbaBot::Todo  qw(todo_add todo_remove todo_list todo_rearrange);


use POE;
use POE::Component::Client::DNS;
use POE::Component::IRC::Common qw(parse_user l_irc);
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::BotCommand;
use Storable;

use constant {
  USER_DATE     => 0,
  USER_MSG      => 1,
  DATA_FILE     => 'seen',
  SAVE_INTERVAL => 20 * 60, # save state every 20 mins
};

my $seen = { };
$seen = retrieve(DATA_FILE) if -s DATA_FILE;



$| = 1; # turn buffering off

# before starting, create a pid file

open (my $fh, ">", "birba.pid");
print $fh $$;
close $fh;
undef $fh;

# initialize the db

my $reconnect_delay = 500;

my %serverconfig = (
		    'nick' => 'Birba',
		    'ircname' => "Birba the Bot",
		    'username' => 'birbabot',
		    'server' => "irc.syrolnet.org",
		    'port' => 7000,
		    'usessl' => 1,
		   );

my %botconfig = (
		 'channels' => "#lamerbot",
		 'botprefix' => "@",
		 'rsspolltime' => 600, # default to 10 minutes
		 'dbname' => "bot.db",
		 'admins' => 'nobody!nobody@nowhere',
		);

# initialize the local storage
my $localdir = File::Spec->catdir('data','rss');
make_path($localdir) unless (-d $localdir);

my $config_file = $ARGV[0];
my $debug = $ARGV[1];

show_help() unless $config_file;

### configuration checking 
override_defaults(\%serverconfig, read_config($config_file));
override_defaults(\%botconfig, read_config($config_file));

print "Bot options: ", Dumper(\%botconfig),
  "Server options: ", Dumper(\%serverconfig);

my $dbname = $botconfig{'dbname'};

my @channels = split(/ *, */, $botconfig{'channels'});

# build the regexp of the admins
my @adminregexps = process_admin_list($botconfig{'admins'});

# when we start, we check if we have all the tables.  By no means this
# guarantees that the tables are correct. Devs, I'm looking at you
create_bot_db($dbname) or die "Errors while updating db tables";

# be sure that the feeds are in the channels we join
rss_clean_unused_feeds($dbname, \@channels);

### starting POE stuff

my $irc = POE::Component::IRC::State->spawn(%serverconfig) 
  or die "WTF? $!\n";

my $dns = POE::Component::Client::DNS->spawn();

POE::Session->create(
    package_states => [
        main => [ qw(_start
		     _default
		     irc_001 
		     irc_disconnected
		     irc_botcmd_seen
		     irc_botcmd_todo
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
		     irc_public
                    irc_join
                    irc_part
                    irc_quit
		    save
                    irc_ctcp_action
		     rss_sentinel
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
            gi => 'Do a google images search.',
            gv => 'Do a google video search.',
            seen => 'Search a user',
            todo => 'add something to the channel TODO; todo [add | done | list | rearrange]',
            kw => 'Manage the keywords: kw foo is bar; kw forget foo',
            x => 'Translate some text from lang to lang (where language is a two digit country code), for example: "x en it this is a test".',
            imdb => 'Query the Internet Movie Database (If you want to specify a year, put it at the end). Alternatively, takes one argument, an id or link, to fetch more data.',
		    },
            In_channels => 1,
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


sub bot_says {
  my ($where, $what) = @_;
  return unless ($where and $what);
  print print_timestamp(), "I'm gonna say $what on $where\n";
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
  


sub irc_botcmd_rss {
  my $nick = (split /!/, $_[ARG0])[0];
  my ($where, $arg) = @_[ARG1, ARG2];
  my @args = split / +/, $arg;
  my ($action, $feed, $url) = @args;
  if (($action eq 'add') &&
      $feed && $url) {
    my $reply = rss_add_new($dbname, $feed, $where, $url);
    bot_says($where, "$reply");
  }
  elsif (($action eq 'del') && $feed) {
    my ($reply, $purged) = rss_delete_feed($dbname, $feed, $where);
    if ($reply) {
      bot_says($where, $reply);
      if ($purged) {
	unlink File::Spec->catfile($localdir, $feed);
      }
    } else {
      bot_says($where, "Problems deleting $feed");
    }
  }
  elsif ($action eq 'list') {
    my $reply = rss_list($dbname, $where);
    bot_says($where, $reply);
  }
  elsif ($action eq 'show') {
    my @replies = rss_give_latest($dbname, $feed);
    foreach my $line (@replies) {
      bot_says($where, $line);
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
    $irc->yield(ctcp => $where, "ACTION slaps $arg");
    return;
}

sub irc_botcmd_g {
  my ($where, $arg) = @_[ARG1, ARG2];
  bot_says($where, search_google($arg, "web"));
}

sub irc_botcmd_gi {
  my ($where, $arg) = @_[ARG1, ARG2];
  bot_says($where, search_google($arg, "images"));
}

sub irc_botcmd_gv {
  my ($where, $arg) = @_[ARG1, ARG2];
  bot_says($where, search_google($arg, "video"));
}

sub irc_botcmd_x {
  my ($where, $arg) = @_[ARG1, ARG2];
  if ($arg =~ m/^\s*([a-z]{2,3})\s+([a-z]{2,3})\s+(.*)\s*$/) {
    bot_says($where, google_translate($3, $1, $2));
  } else {
    bot_says($where, "Example: x hr it govno");
  }
}

sub irc_botcmd_kw {
  my ($who, $where, $arg) = @_[ARG0, ARG1, ARG2];
  print print_timestamp(), "$who, $where, $arg\n";
  if ($arg =~ m/^\s*([^\s]+)\s+is also\s+(.*)\s*$/)  {
    bot_says($where, kw_add($dbname, $who, lc($1), $2));
  } 
  elsif ($arg =~ m/^\s*([^\s]+)\s+is\s+(.*)\s*$/)  {
    bot_says($where, kw_new($dbname, $who, lc($1), $2));
  } 
  elsif ($arg =~ m/^\s*forget\s*([^\s]+)\s*(\w+)\s*$/) {
    bot_says($where, kw_remove($dbname, $who, lc($1), $2));
  }
}


sub irc_botcmd_imdb {
  my ($where, $arg) = @_[ARG1, ARG2];
  bot_says($where, search_imdb($arg));
}


sub irc_botcmd_geoip {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    $irc->yield(privmsg => $where => BirbaBot::Geo::geo_by_name_or_ip($arg));
    return;
}

sub irc_botcmd_todo {
  my ($who, $chan, $arg) = @_[ARG0, ARG1, ARG2];
  my $nick = (split /!/, $_[ARG0])[0];
#  bot_says($chan, $irc->nick_channel_modes($chan, $nick));
  unless (($irc->is_channel_operator($chan, $nick)) or 
	  ($irc->nick_channel_modes($chan, $nick) =~ m/[aoq]/))
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
    my ($type, $host) = $arg =~ /^(?:(\w+) )?(\S+)/;

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


sub irc_001 {
    my ($kernel, $sender) = @_[KERNEL, SENDER];

    # Since this is an irc_* event, we can get the component's object by
    # accessing the heap of the sender. Then we register and connect to the
    # specified server.
    my $irc = $sender->get_heap();

    print print_timestamp(), "Connected to ", $irc->server_name(), "\n";

    # we join our channels
    $irc->yield( join => $_ ) for @channels;
    # here we register the rss_sentinel
    $kernel->delay_set("rss_sentinel", 30);  # first run after 30 seconds
    return;
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

    add_nick($nick, "joining $chan");
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
    print print_timestamp(), "$nick said $what in $channel\n";
    add_nick($nick, "on $channel saying: $what");
    if ( my ($kw) = $what =~ /^([^\s]+)\?/ ) {
      bot_says($channel, kw_query($dbname, lc($1))) 
    }
    elsif ($what =~ /((AH){2,})/) {
      bot_says($channel, "AHAHAHAHAHAH!")
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
  $target =~ s/\s+//g;
  print "processing seen command\n";
  if ($seen->{l_irc($target)}) {
    my $date = localtime $seen->{l_irc($target)}->[USER_DATE];
    my $msg = $seen->{l_irc($target)}->[USER_MSG];
    $irc->yield(privmsg => $channel, "$nick: I last saw $target at $date $msg");
  } elsif ($irc->is_channel_member($channel, $target)) {
    $irc->yield(privmsg => $channel,
		"$nick: $target is here, but $target didn't say a word, AFAIK");
  }
  else {
    $irc->yield(privmsg => $channel, "$nick: I haven't seen $target");
  }
}



sub rss_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
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
  my @masks = split(/\s*,\s*/, shift);
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


exit;

