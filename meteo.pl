#!/usr/bin/perl 

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;
use Encode;

use Data::Dumper;
use URI::Escape;
use XML::Parser;

my $ua = LWP::UserAgent->new;
$ua->timeout(10); # 5 seconds of timeout
$ua->show_progress(1);
#$ua->default_header('Referer' => 'http://laltromondo.dynalias.net');


sub query_meteo {
  my $location = shift;
  return "No location provided" unless $location;
  my $query = uri_escape($location);
  print "Query google for $query";
  my $response = $ua->get("http://www.google.ca/ig/api?weather=$location");
  return "Failed query" unless $response->is_success;
  my $xml = $response->decoded_content();
  my %meteodata;
  my $intag;
  my $parser = new XML::Parser(Style => 'Tree');
  my $data = $parser->parse($xml);
  print Dumper($data);
  return "Okki";
  
}

print query_meteo($ARGV[0]);


