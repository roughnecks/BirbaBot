#!/usr/bin/perl
# -*- mode: cperl -*-

# This library is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

use strict;
use warnings;

use File::Spec;
use File::Path;
use Data::Dumper;
use lib './BirbaBot/lib';
use BirbaBot::RSS qw/rss_create_db
		     rss_add_new
		     rss_get_my_feeds
		    /;


# initialize the db
my $dbname = "rss.db";

unless (-f $dbname) {
  rss_create_db($dbname);
  rss_add_new($dbname,
	      'laltrowiki',
              '#l_altro_mondo',
              'http://laltromondo.dynalias.net/~iki/recentchanges/index.rss');
  rss_add_new($dbname,
	      'lamerbot',
              '#l_altro_mondo',
              'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');
  rss_add_new($dbname,
	      'lamerbot',
              '#lamerbot',
              'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss');

}
    
# initialize the local storage
my $localdir = File::Spec->catdir('data','rss');
File::Path->make_path($localdir) unless (-d $localdir);

my $feeds = rss_get_my_feeds($dbname, $localdir);
print Dumper($feeds);

