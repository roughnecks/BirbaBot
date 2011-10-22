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
		     search_bash
		     search_urban
		  );

our $VERSION = '0.01';

use LWP::UserAgent;
use HTTP::Response;
use HTTP::Request::Common;
use Encode;
use HTML::Parser;

use JSON::Any;
use BirbaBot::Shorten qw(make_tiny_url);
use Data::Dumper;
use URI::Escape;
# use Data::Dumper;

my $ua = LWP::UserAgent->new;
$ua->timeout(10); # 5 seconds of timeout
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
  return ("imdb.com is not reponding properly ") unless $imdbresult->is_success;

  if ($imdbresult->base =~ m!/title/(tt[0-9]{3,})!) {
    my ($url, $imdb) = imdb_query_api($1);
    if ($imdb) {
      return "${bbold}$imdb->{Title}${ebold}, $imdb->{Year}, directed by $imdb->{Director}, with $imdb->{Actors}. Genre: $imdb->{Genre}. Rating: $imdb->{Rating}. ${bbold}http://imdb.com/title/$imdb->{ID}$ebold $imdb->{Plot}";
    } else {
      return "Sorry, the api failed us! Go to  ${bbold}http://imdb.com/title/$1${ebold}"
    }
  }

  my @queryids = imdb_scan_for_titles($imdbresult->content);
  undef $imdbresult;   # free the memory now
  my @output;
  while (@queryids) {
    my $arrayref = shift(@queryids);
    my ($url, $imdb) = imdb_query_api($arrayref->[1]);
    if ($imdb) {
      push @output, "${bbold}$imdb->{Title}${ebold}, $imdb->{Year}, directed by $imdb->{Director}. Genre: $imdb->{Genre}. Rating: $imdb->{Rating}. ${bbold}http://imdb.com/title/$imdb->{ID}$ebold";
    } else {
      my $scrapedtitle = $arrayref->[0];
      $scrapedtitle =~ s/&(\w+|#x[0-9a-zA-Z]+);/ /g; # to fix
      push @output, "$scrapedtitle ${bbold}${url}${ebold}";
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


sub search_bash {
  my $response = $ua->get("http://bash.org/?random");

  my $rawtext = $response->decoded_content();
  my $inquote = 0;
  my $quotecount = 0;
  my @quotes;
  my $inbashid = 0;
  HTML::Parser->new(api_version => 3,
		    handlers    => [start => [ sub {
						 my ($tag, $attr) = @_;
						 if ($tag &&
						     ($tag eq 'p') &&
						     $attr->{class} &&
						     ($attr->{class} eq 'qt')) {
						   $inquote++;
						 } elsif (
							  $tag &&
							  ($tag eq 'p') &&
							  $attr->{class} &&
							  ($attr->{class} eq 'quote')) 
						   {
						     $inbashid++;
						   }
					       }, "tagname, attr"],
				    end   => [ sub {my $tag = shift;
						    if (($inquote) && ($tag eq 'p')) {
						      $inquote--;
						      $quotecount++;
						    }
						    elsif (($inbashid) && ($tag eq 'p')) {
						      $inbashid--;
						    }
						  }, "tagname"],
				    text  => [ sub {
						 my $line = shift;
						 chomp $line;
						 if ($inquote) {
						   $quotes[$quotecount] .=
						     encode("utf-8", $line) . "\n";
						 } elsif ($inbashid) {
						   if ($line =~ m/(#\d+)/) {
						     $quotes[$quotecount] .= 
						       $bbold .
							 "[" . $1 . "]" . 
							   $ebold . " ";
						   }
						 }
					       }, "dtext"],
				   ],
		    empty_element_tags => 1,
		    marked_sections => 1,
		    unbroken_text => 0,
		    ignore_elements => ['script', 'style'],
		   )->parse($rawtext) || return "Something went wrong: $!\n";;
  return $quotes[0];
}

sub search_urban {
  my $query = shift;
  my $results = process_urban($query);
  my $outstring;
  my $counter = 1;
#  print Dumper($results);
  while (@$results && ($counter < 6))  {
    my $res = shift(@$results);
    $outstring .= $bbold . $counter . "." . $ebold . " " .  $res->{'term'} . " " .
      $res->{'definition'} . " " . $res->{'example'} . "; ";
    $counter++;
  }
  if ($outstring) {
    return $outstring;
  } else {
    return "No results found";
  }
}


sub process_urban {
  my $baseurl = 'http://www.urbandictionary.com/define.php?term=';
  my $query = shift;
  my $response = $ua->get($baseurl . uri_escape($query));
  return [] unless $response->is_success;
  my $rawtext = $response->decoded_content();
  $rawtext =~ s/\n/ /gs;
  $rawtext =~ s/\r/ /gs;
  $rawtext =~ s/  +/ /gs;
  my $in_entry;
  my $in_definition;
  my $in_example;
  my $counter = -1;
  my @output;

  HTML::Parser->new(
		    api_version => 3,
		    handlers    => [
		    start => [ sub {
				 my ($tag, $attr) = @_;
				 if ($tag &&
				     ($tag eq 'td') &&
				     $attr->{class} &&
				     ($attr->{class} eq 'word')) {
				   $in_entry = $tag;
				   $counter++;
				   $output[$counter] = {'term' => "",
							'definition' => "",
							'example' => "",
						       };
#				   print "start word $tag $counter\n";
				 } 
				 elsif (
					  $tag &&
					  ($tag eq 'div') &&
					  $attr->{class} &&
					  ($attr->{class} eq 'definition')) 
				   {
				     $in_definition = $tag;
				     print "start $tag def\n";
				   }
				 elsif (
					$tag &&
					($tag eq 'div') &&
					$attr->{class} &&
					($attr->{class} eq 'example'))
				   {
				     $in_example = $tag;
#				     print "start $tag example\n";
				   }
			       }, "tagname, attr"],
		    end   => [ sub {my $tag = shift;
				    if (($in_entry) && ($tag eq $in_entry)) {
				      $in_entry = 0;
#				      print "\nend $tag entry\n";
				    }
				    elsif (($in_definition) && ($tag eq $in_definition)) {
				      $in_definition = 0;
#				      print "\nend $tag def\n";
				    }
				    elsif (($in_example) && ($tag eq $in_example)) {
				      $in_example = 0;
#				      print "\nend $tag example\n";
				    }
				  }, "tagname"],
		    text  => [ sub {
				 my $line = shift;
				 chomp $line;
				 if ($in_entry) {
				   $output[$counter]->{'term'} .=  encode("utf-8", $line);
#				   print $line;
				 } elsif ($in_definition) {
				   $output[$counter]->{'definition'} .=  encode("utf-8", $line);
#				   print $line;
				 } elsif ($in_example) {
				   $output[$counter]->{'example'} .=  encode("utf-8", $line);
#				   print $line;
				 }
			       }, "dtext"],
		   ],
		    empty_element_tags => 1,
		    marked_sections => 1,
		    unbroken_text => 1,
		    ignore_elements => ['script', 'style'],
		   )->parse($rawtext) || return "Something went wrong: $!\n";;
  return \@output;
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
