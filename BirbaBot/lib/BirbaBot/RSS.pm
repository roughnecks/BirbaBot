# -*- mode: cperl -*-

package BirbaBot::RSS;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(rss_create_db
		    rss_add_new
		    rss_get_my_feeds
		  );

our $VERSION = '0.01';


use XML::RSS;
use LWP::UserAgent;
use DBI;
use BirbaBot::Shorten;


=head2 rss_create_db($dbname);

Create the db tables if they don't exist.

    CREATE TABLE IF NOT EXISTS rss (
        feedname                VARCHAR(30) PRIMARY KEY NOT NULL,
        url                     TEXT UNIQUE
    );
    
    CREATE TABLE IF NOT EXISTS channels (
        f_handle                VARCHAR(30) NOT NULL,
        f_channel               VARCHAR(30) NOT NULL,
        active                  BOOLEAN,
        FOREIGN KEY(f_handle)   REFERENCES rss(feedname)
    );
    
    CREATE TABLE IF NOT EXISTS feeds (
        id                      INTEGER PRIMARY KEY,
        date                    DATETIME,
        f_handle                VARCHAR(30) NOT NULL,
        title                   VARCHAR(255),
        author                  VARCHAR(255),
        url                     TEXT UNIQUE,
        FOREIGN KEY(f_handle)   REFERENCES rss(feedname)
    );

=cut

sub rss_create_db {
  my $dbname = shift;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");

  my $foreignkeyspragma = $dbh->prepare('PRAGMA foreign_keys = ON;');
  $foreignkeyspragma->execute();

  my $sthrss = $dbh->prepare('CREATE TABLE IF NOT EXISTS rss (
        f_handle        VARCHAR(30) PRIMARY KEY NOT NULL,
        url             TEXT UNIQUE);');
  $sthrss->execute();

  my $sthchans = $dbh->prepare('CREATE TABLE IF NOT EXISTS channels (
        f_handle        VARCHAR(30) NOT NULL,
        f_channel       VARCHAR(30) NOT NULL,
        FOREIGN KEY(f_handle) REFERENCES rss(f_handle) ON DELETE CASCADE);');
  $sthchans->execute();

  my $sthfeeds = $dbh->prepare('CREATE TABLE IF NOT EXISTS feeds (
        id                      INTEGER PRIMARY KEY,
        date                    DATETIME,
        f_handle                VARCHAR(30) NOT NULL,
        title                   VARCHAR(255),
        author                  VARCHAR(255),
        url                     TEXT UNIQUE,
        FOREIGN KEY(f_handle) REFERENCES rss(f_handle));');
  $sthfeeds->execute();
  $dbh->disconnect;
}

=head2 add_new_rss($dbname, $feedname, $channel, $url)

This function adds a new feed to watch, taking the dbname, the
feedname, the channel to output and the url to watch.

=cut


sub rss_add_new {
  my ($dbname, $feedname, $channel, $url) = @_;

  # sanity check
  return 0 unless ($feedname =~ m/^\w+$/s);

  # our queries
  my $add_to_rss_query = 'INSERT INTO rss VALUES (?, ?);'; # f_handle & url

  # f_handle, channel, active
  my $add_to_channels_query = 'INSERT INTO channels VALUES (?, ?);'; # f_handle & f_channel

  # connect
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");

  # do the 2 queries
  my $rssq = $dbh->prepare($add_to_rss_query);
  $rssq->execute($feedname, $url);

  my $chanq = $dbh->prepare($add_to_channels_query);
  $chanq->execute($feedname, $channel);

  # we should return the errors, but for now go without
  $dbh->disconnect;
  return 1;
}

sub rss_get_my_feeds {
  my ($dbname, $datadir) = @_;
  my $feeds = rss_fetch($dbname, $datadir);
  return dispatch_feeds($dbname, $feeds);
}


=head2 get_the_rss_to_fetch($dbname)

Query the db to see which urls we need to fetch

=cut


sub get_the_rss_to_fetch {
  my $dbname = shift;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $sth = $dbh->prepare('SELECT DISTINCT url, f_handle FROM rss;');
  $sth->execute();
  my %rsses;
  while (my @data = $sth->fetchrow_array()) {
    my $rss = $data[1];
    my $value = $data[0];
    $rsses{$rss} = $value;
  }
  $dbh->disconnect;
  return %rsses
}


=head2 rss_fetch($dbname, $datadir)

It fetches the feeds, dumps them in the db, and return an hash reference like this:
     
     {
       'lamerbot' => [
                       {
                         'link' => 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=commitdiff;h=d45c48b6303defb3977eaad68cbfbfd080b74c3a',
                         'desc' => 'new sql: date fixes',
                         'author' => 'roughnecks <simcana@gmail.com>',
                         'title' => 'new sql: date fixes'
                       }
                     ]
     };
So the next step is to dispatch the feed to the relative channels

=cut


sub rss_fetch {
  my ($dbname, $datadir) = @_;
  # initialize the user agent
  my %output;
  my %urls = get_the_rss_to_fetch($dbname);
  my $ua = LWP::UserAgent->new(timeout => 10); # we can't wait too much
  $ua->agent('Mozilla' . $ua->_agent);
#  $ua->show_progress(1);

  # here we open the db;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", "", "", { PrintError=>0 });

  # and here we start the routineca
  foreach my $feedname (keys %urls) {
    my @outputfeed;
    unless ($feedname =~ m/^\w+$/s) {
      print "Warning: the name of the rss must be alphanumeric", 
        " + underscore only!\n";
      # no next!
      next;
    }
    print "Fetching data for $feedname\n";
    my $destfile = File::Spec->catfile($datadir, $feedname);
    my $response = $ua->mirror($urls{$feedname}, $destfile);
    # now, as far as I understand, the "mirror" response doesn't return
    # the content, which is actually stored in the file.
    # So I guess we either do 'get' request, or we open the file
    if ($response->is_success) {
      my $rss = XML::RSS->new();
      $rss->parsefile($destfile);

      # create a table to hold the data, if doesn't exist yet.
      my $sth = 
        $dbh->prepare("INSERT INTO feeds VALUES (NULL, DATETIME('NOW'),  ?, ?, ?, ?)");
      foreach my $item (@{$rss->{'items'}}) {
        $sth->execute(
                      $feedname,
                      $item->{'title'},
                      $item->{'author'},
                      $item->{'link'});
        unless ($sth->err) {
          # here we push the new feed in a multidimensional hash
          push @outputfeed,
            {'title' =>  $item->{'title'},
             'author' => $item->{'author'},
             'link' =>   $item->{'link'} };
        }
      } 
      $output{$feedname} = \@outputfeed;
    }
  }
  $dbh->disconnect;
  return \%output;
}

=head2 dispatch_feeds($dbname, $hashref)

Take as argument the db name, and the output of rss_fetch.

Query the db to see where the the feeds should go, parse them and output a hash references with #channel => [news1, news2] pairs. 

=cut


sub dispatch_feeds {
  my ($dbname, $hashref) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $processed_feeds = process_feeds($hashref);
  my $sth = $dbh->prepare('SELECT f_channel FROM channels WHERE f_handle = ?');
  my %output;

  # for each $feedname provided by the rss processor, we find the
  # destinations. We return an hash with #channel => [$news1, $news2]
  # so the bot can loop over that and *finally* print the shit

  foreach my $feedname (keys %$processed_feeds) {
    $sth->execute($feedname);
    while (my @destinations = $sth->fetchrow_array()) {
      my $channel = $destinations[0];
      $output{$channel} = [] unless exists $output{$channel};
      my $stuff = $processed_feeds->{$feedname};
      foreach my $news (@$stuff) {
	push @{$output{$channel}}, $news;
#	print "To $channel: $channel :::", "$news", "\n";
      }
    }
  }
  $dbh->disconnect;
  return \%output;
}


sub process_feeds {
  my $hashref = shift;
  my %output;
  foreach my $feedname (keys %$hashref) {
    my @processed;
    my $feedsref = $hashref->{$feedname};
    my @feeds = splice(@$feedsref, 0, 5); # output just the last 5, OK?
    # now loop over the feeds and create the string
    while(@feeds) {
      my $news = shift(@feeds);
      my $string = "${feedname}:: ";
      if ($news->{'title'}) {
	$string .= $news->{'title'} . " ";
      } else {
	next # wtf, no title?
      }
      if ($news->{'link'}) {
	# ENABLE ME!
	$string .= "<" . BirbaBot::Shorten::make_tiny_url($news->{'link'}) . "> ";
	# $string .= "<" . $news->{'link'} . "> ";
      } else {
	next # wtf, no link?
      }
      if ($news->{'author'}) {
	$string .= "(" . $news->{'author'} . ")";
      }
      push @processed, $string;
    }
    $output{$feedname} = \@processed;
  }
  return \%output;
}

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

BirbaBot - Perl extension for blah blah blah

=head1 SYNOPSIS

  use BirbaBot;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for BirbaBot, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

melmoth, E<lt>melmoth@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by melmoth

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
