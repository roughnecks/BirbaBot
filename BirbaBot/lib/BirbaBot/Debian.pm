# -*- mode: cperl -*-

package BirbaBot::Debian;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(deb_pack_versions deb_pack_search);

our $VERSION = '0.01';

my $bbold = "\x{0002}";
my $ebold = "\x{000F}";



=head2 deb_pack_versions()

my @out = deb_pack_versions($arg,
		            $relfiles_basepath, 
		            $debconfig{debrels});

=cut

sub deb_pack_versions {
  my ($arg, $path, $relfiles) = @_;
  return unless (@$relfiles);
  my @out;
  my $pack;
  if ($arg =~ m/^\s*(\S+)\s*/) {
    $pack = $1;
  } else {
    return "Invalid argument";
  }
  foreach my $rel (@$relfiles) {
    next unless ($rel->{rel} and $rel->{url});
    my $file = File::Spec->catfile($path, $rel->{rel});
    my $result = parse_debfiles($file, $pack, 1);
    if ($result) {
      push @out, $bbold . $rel->{rel} . $ebold . ' => ' . $result;
    }
  }
  return @out;
}


=head2 deb_pack_search()

=cut


sub deb_pack_search {
  my ($arg, $path, $relfiles) = @_;
  my @results;
  my $pack;
  if ($arg =~ m/^\s*(\S+)\s*/) {
    $pack = $1;
  } else {
    return "Invalid argument";
  }
  foreach my $rel (@$relfiles) {
    next unless ($rel->{rel} and $rel->{url});
    my $file = File::Spec->catfile($path, $rel->{rel});
    push @results, parse_debfiles($file, $pack);
  }
  # print "Search results: ", @results;
  my %out;
  while (@results) {
    my $pack = shift(@results);
    $out{$pack} = 1;
  };
  @results = refine_results($arg, \%out);
  return "No matches" unless @results;
  if ((scalar @results) > 20) {
    splice @results, 19;
    push @results, "and more...."
  };
  return "Found packs: " . join(", ", @results);
}



sub parse_debfiles {
  my ($file, $pack, $exact) = @_;
  return unless $pack;
  open (my $fh, "<:encoding(utf8)", $file) or die "Could not open $file: $!";
  my $foundmatch;
  my @packs;
  while (<$fh>) {
    my $line = $_;
    if ($exact) {
      if ($line =~ m/^\Q$pack\E\s+\((.+?)\)\s+(\[.+\])?.+$/i) {
	$foundmatch = $1;
        if ($2) {
          $foundmatch .= " $2";
        }
	last;
      }
    } else {
      if ($line =~ m/^(^\S*?\Q$pack\E\S*)\s/i) {
	# print "Found $1 for $pack\n";
	push @packs, $1;
      }
    }
  }
  close $fh;
  if ($exact) {
    return $foundmatch;
  } else {
    return @packs;
  }
}

sub refine_results {
  my ($arg, $matches) = @_;
  my @terms = split(/\s+/, $arg);
  my $first = shift @terms; # the first one is already checked
  # next 
  my @got;
  my @notexact;
  foreach my $res (sort(keys %$matches)) {
    if ($res =~ m/^\Q$first\E/) {
      push @got, $res;
    } else {
      push @notexact, $res;
    }
  }
  push @got, @notexact;
  # return now if there is only one term
  return @got unless (@terms);

  my @refined;
  while (@got) {
    my $candidate = shift(@got);
    # print "Examining $candidate...\n";
    my $c = 0;

    foreach my $term (@terms) {
      if ($candidate =~ /\Q$term\E/) {
	# if there is a match, increment
	$c++
      }
    }
    # now, we compare the scalar @terms with with $c

    # print 'Check: ', $c, "\n";
    if ($c == (scalar @terms)) {
      push @refined, $candidate;
      # print "FOUND ",  $candidate, "\n";;
    } else {
      # print "... $c ...";
    }
  }
  return @refined;
}


1;
