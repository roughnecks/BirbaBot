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
use BirbaBot::RSS qw(rss_create_db
		     rss_add_new
		     rss_delete_feed
		     rss_get_my_feeds
		   );
use BirbaBot::Geo;
use BirbaBot::Searches qw(search_google
			  google_translate
			);


use POE;
use POE::Component::Client::DNS;
use POE::Component::IRC;
use POE::Component::IRC::Plugin::BotCommand;


# initialize the db
my $dbname = "rss.db";

unless (-f $dbname) {
  rss_create_db($dbname);
  rss_add_new($dbname,
	      'laltrowiki',
              '#l_altro_mondo',
              'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss');
  rss_add_new($dbname,
	      'ansa',
              '#l_altro_mondo',
              'http://ansa.it/web/notizie/rubriche/topnews/topnews_rss.xml');
  rss_add_new($dbname,
	      'birbabot',
              '#l_altro_mondo',
              'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');
  rss_add_new($dbname,
	      'boingboing',
              '#l_altro_mondo',
              'http://feeds.boingboing.net/boingboing/iBag');
  rss_add_new($dbname,
	      'slashdot',
              '#l_altro_mondo',
              'http://rss.slashdot.org/Slashdot/slashdot');
  rss_add_new($dbname,
	      'birbabot',
              '#lamerbot',
              'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');
}
    
# initialize the local storage
my $localdir = File::Spec->catdir('data','rss');
make_path($localdir) unless (-d $localdir);

my $config_file = $ARGV[0];
my $debug = $ARGV[1];

show_help() unless $config_file;

### configuration checking 

my $configuration = read_config($config_file);

print Dumper($configuration) if $debug;

my $nick = $configuration->{'nick'};
my $ircname = $configuration->{'ircname'};
my $server = $configuration->{'server'};

show_help("Missing configuration options\n") 
  unless ($configuration->{nick} and
	$configuration->{ircname} and 
	$configuration->{server});

my @channels = split(/ *, */, $configuration->{'channels'});


if ($debug) {
  print "Connecting to $server with nick $nick and ircname $ircname, ",
    "joining channels ", 
      join(" and ", @channels), "\n";
}

### starting POE stuff

my $irc = POE::Component::IRC->spawn(
				     # TODO: before using this
				     # directly would be better to
				     # clean it up, ok?
				     %$configuration
) or die "WTF? $!\n";

my $dns = POE::Component::Client::DNS->spawn();

POE::Session->create(
    package_states => [
        main => [ qw(_start
		     _default
		     irc_001 
		     irc_botcmd_slap
		     irc_botcmd_geoip
		     irc_botcmd_lookup
		     irc_botcmd_rss
		     irc_botcmd_g
		     irc_botcmd_gi
		     irc_botcmd_gv
		     irc_botcmd_x
		     rss_sentinel
		     dns_response) ],
    ],
);

$poe_kernel->run();

## just copy and pasted, ok?

sub _start {
    $irc->plugin_add('BotCommand', 
		     POE::Component::IRC::Plugin::BotCommand->new(
								  Commands => {
            slap   => 'Takes one argument: a nickname to slap.',
            lookup => 'Takes two arguments: a record type (optional), and a host.',
	    geoip => 'Takes one argument: an ip or a hostname to lookup',
	    rss => 'RSS [ add | del ] <name> <url>: manage RSS subscriptions',
            g => 'Do a google search',
            gi => 'Do a google images search',
            gv => 'Do a google video search',
            x => 'Translate the text with, for example, x en it this is a test',
		    },
            In_channels => 1,
 	    In_private => 1,
            Addressed => 0,
            Prefix => "@",
            Eat => 1,
            Ignore_unknown => 1,
								  
								 ));
    $irc->yield( register => 'all' );
    $irc->yield( connect => { } );
    return;
}

sub bot_says {
  my ($where, $what) = @_;
  return unless ($where and $what);
  $irc->yield(privmsg => $where => $what);
  return;
}


sub irc_botcmd_rss {
  my $nick = (split /!/, $_[ARG0])[0];
  my ($where, $arg) = @_[ARG1, ARG2];
  my @args = split / +/, $arg;
  my ($action, $feed, $url) = @args;
  if (($action eq 'add') &&
      $feed && $url) {
    rss_add_new($dbname, $feed, $where, $url);
    bot_says($where, "$feed added!");
  } elsif (($action eq 'del') && $feed) {
    my ($reply, $purged) = rss_delete_feed($dbname, $feed, $where);
    if ($reply) {
      bot_says($where, "$reply");
      if ($purged) {
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





sub irc_botcmd_geoip {
    my $nick = (split /!/, $_[ARG0])[0];
    my ($where, $arg) = @_[ARG1, ARG2];
    $irc->yield(privmsg => $where => BirbaBot::Geo::geo_by_name_or_ip($arg));
    return;
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




sub irc_001 {
    my ($kernel, $sender) = @_[KERNEL, SENDER];

    # Since this is an irc_* event, we can get the component's object by
    # accessing the heap of the sender. Then we register and connect to the
    # specified server.
    my $irc = $sender->get_heap();

    print "Connected to ", $irc->server_name(), "\n";

    # we join our channels
    $irc->yield( join => $_ ) for @channels;
    # here we register the rss_sentinel
    $kernel->delay_set("rss_sentinel", 30);  # first run after 30 seconds
    return;
}

sub irc_public {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

    if ( my ($rot13) = $what =~ /^rot13 (.+)/ ) {
        $rot13 =~ tr[a-zA-Z][n-za-mN-ZA-M];
        $irc->yield( privmsg => $channel => "$nick: $rot13" );
    }
    return;
}

sub rss_sentinel {
  my ($kernel, $sender) = @_[KERNEL, SENDER];
  print "Starting fetching RSS...";
  my $feeds = rss_get_my_feeds($dbname, $localdir);
  foreach my $channel (keys %$feeds) {
    foreach my $feed (@{$feeds->{$channel}}) {
      $irc->yield( privmsg => $channel => $feed);
    }
  }
  print "done!\n";
  # set the next loop
  $kernel->delay_set("rss_sentinel", 869) # now fetch every ~15 minutes
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
    print join ' ', @output, "\n";
    return 0;
}



exit;

=head2 read_config

Read the configuration file, which should be passed on the command
line, and return an hashref with key-value pairs for the bot config.

=cut 

sub read_config {
  my $file = shift;
  my %config;
  show_help() unless (-f $file);
  open (my $fh, "<", $file) or die "Cannot read $file $!\n";
  while (<$fh>) {
    my $line = $_;
    # strip whitespace
    chomp $line;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next if ($line =~ m/^#/);
    if ($line =~ m/(\w+)\s*=\s*(.*)/) {
      my $key = $1;
      my $value = $2;
      $value =~ s/^"//;
      $value =~ s/"$//;
      if ($key && $value) {
	$config{$key} = $value;
      }
    }
  }
  close $fh;
  return \%config;
}

=head2 show_help

Well, show the help and exit

=cut



sub show_help {
  my $string = shift;
  print "$string\n" if $string;

  print <<HELP;


This script runs the bot. It takes a mandatory argument with the
configuration file. The configuration file have values like this:

nick = pippo_il_bot
server = irc.syrolnet.org

Blank lines are just ignored. Lines starting with # are ignored too.
Don't put comments on the same line of a key-value pair, OK?
(Otherwise the comment will become part of the value).

Good luck.

HELP
  exit 1;
}
