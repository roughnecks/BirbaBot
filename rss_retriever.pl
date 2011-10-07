#!/usr/bin/perl
# -*- mode: cperl -*-

# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

use strict;
use warnings;

use XML::RSS;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;
use File::Spec;
use File::Path;
use DBI;

# initialize the db
my $dbname = "rss.db";
create_db() unless (-f $dbname);

# initialize the local storage
my $localdir = File::Spec->catdir('data','rss');
File::Path->make_path($localdir) unless (-d $localdir);



my %urls = get_the_rss_to_fetch();
my $output = rss_fetch();
dispatch_feeds($output);


=head2 create_db

Create the db tables if they don't exist.

    CREATE TABLE IF NOT EXISTS rss (
            feedname            VARCHAR(30) PRIMARY KEY NOT NULL,
            url         TEXT UNIQUE
    );
    
    CREATE TABLE IF NOT EXISTS channels (
            f_handle        VARCHAR(30) NOT NULL,
            f_channel   VARCHAR(30) NOT NULL,
            active              BOOLEAN,
        FOREIGN KEY(f_handle) REFERENCES rss(feedname));
    
    CREATE TABLE IF NOT EXISTS feeds (
            id                          INTEGER PRIMARY KEY,
        date                    DATETIME,
        f_handle                VARCHAR(30) NOT NULL,
            title                       VARCHAR(255),
            author                      VARCHAR(255),
            url                 TEXT UNIQUE,
        description             TEXT,
        FOREIGN KEY(f_handle) REFERENCES rss(feedname)
    );

Additionally, add some sample rss

=cut

sub create_db {
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
        description             TEXT,
        FOREIGN KEY(f_handle) REFERENCES rss(f_handle));');
  $sthfeeds->execute();
  $dbh->disconnect;

  add_new_rss('laltrowiki',
              '#l_altro_mondo',
              'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss');
  add_new_rss('lamerbot',
              '#l_altro_mondo',
              'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');
  add_new_rss('lamerbot',
              '#lamerbot',
              'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');
  # all done
}

=head2 add_new_rss($feedname, $channel, $url, $active)

This function adds a new feed to watch.

=cut


sub add_new_rss {
  my ($feedname, $channel, $url) = @_;

  # sanity check
  return 0 unless ($feedname =~ m/^\w+$/s);

  # our queries
  my $add_to_rss_query = 'INSERT INTO rss VALUES (?, ?);'; # f_handle & url

  # f_handle, channel, active
  my $add_to_channels_query = 'INSERT INTO channels VALUES (?, ?);'; 

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

=head2 get_the_rss_to_fetch()

Query the db to see which urls we need to fetch

=cut


sub get_the_rss_to_fetch {
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


=head2 rss_fetch(\%rsses)

This function accept a reference to an hash like this
   
     { lamerbot => http://domain.com/rss.xml,
       lamerbot2 => http://domain.org/rss.xml}

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
  # initialize the user agent
  my %output;
  my $ua = LWP::UserAgent->new(timeout => 10); # we can't wait too much
  $ua->agent('Mozilla' . $ua->_agent);
  $ua->show_progress(1);

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
    my $destfile = File::Spec->catfile($localdir, $feedname);
    my $response = $ua->mirror($urls{$feedname}, $destfile);
    # now, as far as I understand, the "mirror" response doesn't return
    # the content, which is actually stored in the file.
    # So I guess we either do 'get' request, or we open the file
    if ($response->is_success) {
      my $rss = XML::RSS->new();
      $rss->parsefile($destfile);

      # create a table to hold the data, if doesn't exist yet.
      my $sth = 
        $dbh->prepare("INSERT INTO feeds VALUES (NULL, DATETIME('NOW'),  ?, ?, ?, ?, ?)");
      foreach my $item (@{$rss->{'items'}}) {
        $sth->execute(
                      $feedname,
                      $item->{'title'},
                      $item->{'author'},
                      $item->{'link'},
                      $item->{'description'});
        unless ($sth->err) {
          # here we push the new feed in a multidimensional hash
          push @outputfeed,
            {'title' =>  $item->{'title'},
             'author' => $item->{'author'},
             'link' =>   $item->{'link'},
             'desc' =>   $item->{'description'} };
        }
      } 
      $output{$feedname} = \@outputfeed;
    }
  }
  $dbh->disconnect;
  return \%output;
}

=head2 make_tiny_url($url)

Given a url string $url, return a shortened url quering various
tinyurler on the net.

=cut

sub make_tiny_url {
  my $url = shift;
  print $url, "\n";
  my $ua = LWP::UserAgent->new(timeout => 10);
  $ua->agent( 'Mozilla' );
  my $response = $ua->request( POST 'http://api.x0.no/post/', ["u" => $url]);
  my $short; ;
  if ($short = make_tiny_url_x ($ua, $url)) {
    return $short
  } elsif ($short = make_tiny_url_metamark( $ua, $url)) {
    return $short
  }
  else {
    return $url
  }
}

sub make_tiny_url_x {
  my ($ua, $url) = @_;
  my $response = $ua->request( POST 'http://api.x0.no/post/', ["u" => $url]);
  #  print $response->content, "\n";
  if ($response->is_success and $response->content =~ m!(http://[\w.]+/\w+)!) {
    return $1;
  } 
  else {
    return 0;
  };
}

sub make_tiny_url_metamark {
  my ($ua, $url) = @_;
  my $response = $ua->request( POST 'http://metamark.net/api/rest/simple',
			       ["long_url" => $url]);
  if ($response->is_success and $response->content =~ m!(http://[\w.]+/\w+)!) {
    return $1;
  } 
  else {
    return 0;
  }
}

sub dispatch_feeds {
  my $hashref = shift;
  foreach my $feedname (keys %$hashref) {
    print Dumper($hashref->{$feedname});
  }
}
