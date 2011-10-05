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

my %urls = ('wiki' => 'http://laltromondo.dynalias.net/gitweb/?p=LAltroWiki.git;a=rss',
	    'bot' =>    'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=rss',
	    'library' => 'http://theanarchistlibrary.org/rss.xml'
	   );

my $localdir = File::Spec->catdir('data','rss');
File::Path->make_path($localdir) unless (-d $localdir);


my $ua = LWP::UserAgent->new(timeout => 10); # we can't wait too much
			    
$ua->agent('Mozilla/BunnyBot' . $ua->_agent);
$ua->show_progress(1);

foreach my $url (keys %urls) {
  print "Fetching data for $url\n";
  my $destfile = File::Spec->catfile($localdir, $url);
  my $response = $ua->mirror($urls{$url}, $destfile);
  # now, as far as I understand, the "mirror" response doesn't return
  # the content, which is actually stored in the file.
  # So I guess we either do 'get' request, or we open the file
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

