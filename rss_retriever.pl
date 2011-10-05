#!/usr/bin/perl

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

my $dbname = "rss.db";
create_db() unless (-f $dbname);

my %urls = get_the_rss_to_fetch();

# initialize the local storage
my $localdir = File::Spec->catdir('data','rss');
File::Path->make_path($localdir) unless (-d $localdir);

# initialize the user agent
my $ua = LWP::UserAgent->new(timeout => 10); # we can't wait too much
$ua->agent('Mozilla/BunnyBot' . $ua->_agent);
$ua->show_progress(1);

# here we open the db;
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");

foreach my $url (keys %urls) {
  print "Fetching data for $url\n";
  my $destfile = File::Spec->catfile($localdir, $url);
  my $response = $ua->mirror($urls{$url}, $destfile);
  # now, as far as I understand, the "mirror" response doesn't return
  # the content, which is actually stored in the file.
  # So I guess we either do 'get' request, or we open the file
  unless ($url =~ m/^\w+$/s) {
    print "Warning: the name of the rss must be alphanumeric + underscore only!\n";
    next;
  }


  if ($response->is_success) {
    my $rss = XML::RSS->new();
    $rss->parsefile($destfile);
    foreach my $item (@{$rss->{'items'}}) {
      print "title: $item->{'title'}\n";
      print "link: $item->{'link'}\n";
      print "description: $item->{'description'}\n";
    }
  } else {
    print "$url skipped\n"
  }
}
$dbh->disconnect;

exit;

=head2 add_new_rss 

Function to add a new rss

=cut


sub add_new_rss {
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  
  $dbh->disconnect;
}

=head2 create_db

Create a new database if it doesn't exist.

=cut

sub create_db {
  my $create_meta_rss = "CREATE TABLE IF NOT EXISTS rss (
        r_id    	INTEGER PRIMARY KEY,
	date		DATETIME,
	f_handle	VARCHAR(255),
	f_channel	VARCHAR(30),
        url     	TEXT,
        active		BOOLEAN
);";
  my $populate_meta_rss = "INSERT INTO rss VALUES (?, DATETIME('NOW'), ?, ?, ?, ?)";
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $sth = $dbh->prepare($create_meta_rss);
  $sth->execute();
  my $populate = $dbh->prepare($populate_meta_rss);
  $populate->execute(undef, 'laltrowiki', '#l_altromondo', 'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss', 1);
  $populate->execute(undef, 'lamerbot', '#l_altro_mondo', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 1);
  $populate->execute(undef, 'lamerbot', '#lamerbot', 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss', 0);
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
