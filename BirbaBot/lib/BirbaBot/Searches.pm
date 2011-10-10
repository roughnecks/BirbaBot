# -*- mode: cperl -*-

package BirbaBot::Searches;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(
		     search_google
		  );

our $VERSION = '0.01';

use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;

use JSON::Any;
use BirbaBot::Shorten qw(make_tiny_url);
use Data::Dumper;
use URI::Escape;
# use Data::Dumper;

my $ua = LWP::UserAgent->new;
$ua->timeout(5); # 5 seconds of timeout
$ua->show_progress(1);

sub google_translate {
  my ($string, $from, $to);
  unless (($from =~ m/^\w+$/) and ($to =~ m/^\w+$/)) {
    return "Right example query: x it en here goes my text"
  }
  # first, build the url
  
  my $target  = "http://ajax.googleapis.com/ajax/services/language/translate" .
    "?v=1.0&q=" . uri_escape($string) . "&langpair=${from}|${to}";
  my ($result, $excode) = google_json_get_and_check($target);
  if ($excode) {
     return "Huston, we have a problem... The APIs seems broken"
   } else {
     return $result->{'translatedText'}
   }
}


sub search_google {
  my ($query, $type) = @_;
  unless (($type eq "web") or 
	  ($type eq "images") or
	  ($type eq "video")) {
    return "Type unsupported"
  }
  my $target = "http://ajax.googleapis.com/ajax/services/search/" . $type .
    "?q=" . uri_escape($query) . "&v=1.0";
  my ($result, $excode) = google_json_get_and_check($target);
  if ($excode) {
     return "Huston, we have a problem... The APIs seems broken"
   } else {
     return google_process_results($result->{'results'})
   }
}


sub google_json_get_and_check {
  my $url = shift;
  my $jsonresponse = $ua->get($url);
  unless ($jsonresponse->is_success) {
    return ("Huston, we have a problem... Google is not responding on $url", 1);
  }
  my $response = JSON::Any->jsonToObj($jsonresponse->content);
  if (($response->{'responseStatus'} == 200) and 
      ($response->{'responseData'})) {
    return $response->{'responseData'}
  }
   else {
     print Dumper($response);
     return ("Huston, we have a problem... The APIs seems broken", 1);
   }
}



sub google_process_results {
  my $arrayref = shift;
  my @out;
  foreach my $c (0..3) {
    my $result = "";
    my $title =  $arrayref->[$c]->{'titleNoFormatting'};
    my $url = make_tiny_url($arrayref->[$c]->{'url'});
    push @out, "\x{0002}$title\x{000F} <$url>";
  }
  return join (" | ", @out);
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
