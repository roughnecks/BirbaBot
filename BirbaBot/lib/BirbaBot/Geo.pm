# -*- mode: cperl -*-

package BirbaBot::Geo;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(geo_by_name_or_ip);

our $VERSION = '0.01';

use Geo::IP;

my $gi = Geo::IP->new(GEOIP_STANDARD);
$gi->set_charset(GEOIP_CHARSET_UTF8);


=head2 geo_by_name_or_ip($string);

This is the only function exportable by this module. It parses $string and return the locatation of $string, provided it's an ip or a host.

=cut


sub geo_by_name_or_ip {
  my $input = shift;
  my $ip;
  my $hostname;
  if ($input =~ m/(([0-9]{1,3}\.){3}([0-9]{1,3}))/) {
    $ip = $1;
  } elsif ($input =~ m/([\w\.\-]+\.[\w]{1,3})/) {
    $hostname = $1
  } else {
    return "Please provide a hostname or a ip to lookup";
  }
  if ($ip) {
    return lookup_by_ip($ip)
  } elsif ($hostname) {
    return lookup_by_name($hostname)
  } else {
    return "Something went wrong, sorry"
  }
}

sub lookup_by_ip {
  my $ip = shift;
  # ok, the db shipped by debian only support country lookup, no city, no region
  my $country = $gi->country_name_by_addr($ip);
  if ($country) {
    return "$ip is located in $country"
  } else {
    return "I cannot locate $ip, sorry"
  }
}

sub lookup_by_name {
  my $name = shift;
  my $country = $gi->country_name_by_name($name);
  if ($country) {
    return "$name is located in $country"
  } else {
    return "I cannot locate $name, sorry"
  }
}

1;
