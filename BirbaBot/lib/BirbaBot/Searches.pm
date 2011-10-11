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
		     google_translate
		     search_imdb
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

my $bbold = "\x{0002}";
my $ebold = "\x{000F}";


=head2 search_imdb($string)

Query http://www.imdbapi.com/ for a movie. If year is attached (which
must be at the end), do a refined search.

=cut


sub search_imdb {
  my $string = shift;
  return "Query imdb about what?" unless $string;
  $string =~ s/\s+$//;
  # first, we check the input string, and see if it's an imdb url or id
  if ($string =~ m/(tt[0-9]{3,})/) {
    my ($url, $imdb) = imdb_query_api($1);
    if ($imdb) {
      return "${bbold}$imdb->{Title}${ebold}, $imdb->{Year}, directed by $imdb->{Director}, with $imdb->{Actors}. Genre: $imdb->{Genre}. Rating: $imdb->{Rating}. $imdb->{Plot}";
    } else {
      return "Sorry, the api failed us! Go to  ${bbold}http://imdb.com/title/$1${ebold}"
    }
  }
  
  # first, we query the imdb.com site, and give the first 3
  # results. Then we query the api to get the informations. It the api
  # fails, at least we give title and url.
  my $query = uri_escape($string);
  my $imdbresult = $ua->get("http://www.imdb.com/find?s=all&q=$query");
  my @queryids = imdb_scan_for_titles($imdbresult->content);
  undef $imdbresult;   # free the memory now
  my @output;
  while (@queryids) {
    my $arrayref = shift(@queryids);
    my ($url, $imdb) = imdb_query_api($arrayref->[1]);
    if ($imdb) {
      push @output, "${bbold}$imdb->{Title}${ebold}, $imdb->{Year}, directed by $imdb->{Director}. Genre: $imdb->{Genre}. Rating: $imdb->{Rating}. ${bbold}http://imdb.com/title/$imdb->{ID}$ebold";
    } else {
      push @output, "$arrayref->[0] ${bbold}${url}${ebold}";
    }
  }
  return join (" || ", @output);
  # parse the json
  # check if we have all the fields

}

sub imdb_scan_for_titles {
  my $htmlshit = shift;
  $htmlshit =~ s/\r?\n/ /gs;
  my @results;
  my $counter = 0;
  while ($htmlshit =~ m!<a\s+href="/title/(tt[0-9]+)/".*?>([^><]+?)</a>!g) {
    unless ($results[$#results] and ($1 eq $results[$#results]->[1])) {
      push @results, [$2, $1]; # $title, $url
      $counter++;
    }
    last if ($counter == 3);
  }
  print Dumper(\@results);
  return @results;
}

# internal. Query the api for movie's data. If it fails, just return the imdb url

sub imdb_query_api {
  my $id = shift;
  my $target = "http://www.imdbapi.com/?i=$id";
  my $json = $ua->get($target);
  # if it fails, return only the url
  my $imdburl = "http://imdb.com/title/$id";
  return $imdburl unless $json->is_success;
  my $imdb = JSON::Any->jsonToObj($json->content);
  unless (($imdb->{'Response'}) && ($imdb->{'Response'} eq 'True')) {
    return $imdburl
  }
  my @required = qw(ID Title Year Director Actors Rating Genre Plot);
  foreach my $key (@required) {
    unless ($imdb->{$key}) {
      $imdb->{$key} = "N/A";
    }
  }
  return ($imdburl, $imdb); 
}




=head2 google_translate($string, $from, $to)

Query http://ajax.googleapis.com/ajax/services/language/translate for
a $string to translatate from language code $from to language code
$to.

=cut


sub google_translate {
  my ($string, $from, $to) = @_;
  return "Missing paramenters" unless ($string and $from and $to);

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

=head2 search_google($query, $type)

Query http://ajax.googleapis.com/ajax/services/search/$tupe for string $query, where $query must be one of the following: "web", "images" or "video". Self-explaining, I guess.

=cut


sub search_google {
  my ($query, $type) = @_;
  unless (($type eq "web") or 
	  ($type eq "images") or
	  ($type eq "video")) {
    return "Type unsupported"
  }
  return "Search what?" unless $query;

  my $target = "http://ajax.googleapis.com/ajax/services/search/" . $type .
    "?q=" . uri_escape($query) . "&v=1.0";
  my ($result, $excode) = google_json_get_and_check($target);
  if ($excode) {
     return "Huston, we have a problem... The APIs seems broken"
   } else {
     return google_process_results($result->{'results'})
   }
}

# internal to process the json shit
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


# internal to process the hash returned by google_json_get_and_check

sub google_process_results {
  my $arrayref = shift;
  my @out;
  foreach my $c (0..3) {
    my $result = "";
    my $title =  $arrayref->[$c]->{'titleNoFormatting'};
    my $url = make_tiny_url($arrayref->[$c]->{'url'});
    push @out, "${bbold}${title}${ebold} <$url>";
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
