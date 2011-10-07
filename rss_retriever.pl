#!/usr/bin/perl
# -*- mode: cperl -*-

# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

use strict;
use warnings;

use XML::RSS;
use Data::Dumper;
use LWP::UserAgent;
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
rss_fetch();


=head2 create_db

Create the master rss table if it doesn't exist.

=cut

sub create_db {
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");

  my $create_meta_rss = "CREATE TABLE IF NOT EXISTS rss (
        r_id    	INTEGER PRIMARY KEY,
	date		DATE,
	f_handle	VARCHAR(255),
	f_channel	VARCHAR(30),
        url     	TEXT,
        active		BOOLEAN
);";
  my $sth = $dbh->prepare($create_meta_rss);
  $sth->execute();

  my $createtab = 
	"CREATE TABLE IF NOT EXISTS feeds (
        id          	INTEGER PRIMARY KEY,
        feedname        VARCHAR(30),
        date            DATETIME,
        title	    	VARCHAR(255),
        author		VARCHAR(255),
	url	    	TEXT UNIQUE,
	description	TEXT);";
  my $sthfeeds = $dbh->prepare($createtab);
  $sthfeeds->execute();

  $dbh->disconnect;

  add_new_rss('laltrowiki', 
	      '#l_altro_mondo',
	      'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss',
	      1);
  add_new_rss('lamerbot',
	      '#l_altro_mondo',
	      'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss',
	      1);
  add_new_rss('lamerbot',
	      '#lamerbot',
	      'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss',
	      1);
  # all done
}

=head2 add_new_rss($feedname, $channel, $url, $active)

This function adds a new feed to watch.

=cut


sub add_new_rss {
  my ($feedname, $channel, $url, $active) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  return unless ($feedname =~ m/^\w+$/s);
  # first the table to hold the data
  # then update the rss table
  my $populate_meta_rss = "INSERT INTO rss VALUES (NULL, DATE('NOW'), ?, ?, ?, ?)";
  my $populate = $dbh->prepare($populate_meta_rss);
  $populate->execute($feedname, $channel, $url, $active);
  $dbh->disconnect;
}



=head2 get_the_rss_to_fetch()

Query the db to see which urls we need to fetch

=cut


sub get_the_rss_to_fetch {
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $sth = $dbh->prepare('SELECT DISTINCT url,f_handle FROM rss WHERE active=1;');
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
	$dbh->prepare("INSERT INTO feeds VALUES (NULL, ?, DATETIME('NOW'), ?, ?, ?, ?)");
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
  print Dumper(\%output);
  return \%output;
}
