# -*- mode: cperl -*-

package BirbaBot::Shorten;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(make_tiny_url);

our $VERSION = '0.01';

use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;

my $goodurlre = qr!http://[\w\.\-]+/\w+!;

=head2 make_tiny_url($long_url)

This is the only function exported by this module. It takes an
argument with the long url to shorten and return a shortened one,
unless the online services are down or going nuts. If everything
fails, return the long url.

Urls with less than 60 characters are returned without furter
processing.

=cut

sub make_tiny_url {
  my $url = shift;
  return $url unless ((length $url) > 60);
  print "Requesting tinyurl for $url\n";
#  print $url, "\n";
  my $ua = LWP::UserAgent->new(timeout => 10);
  $ua->agent( 'Mozilla' );
  my $short;
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
  my $response = $ua->request( POST 'http://api.x0.no/post/', 
			       ["u" => $url]);
  #  print $response->content, "\n";
  if ($response->is_success and $response->content =~ m!($goodurlre)!) {
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
  if ($response->is_success and $response->content =~ m!($goodurlre)!) {
    return $1;
  } 
  else {
    return 0;
  }
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
