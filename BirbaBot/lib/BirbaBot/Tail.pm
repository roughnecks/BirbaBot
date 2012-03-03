# -*- mode: cperl -*-


package BirbaBot::Tail;
use 5.010001;

use strict;
use warnings;

use File::Basename;
use Encode;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants. 

our @EXPORT_OK = qw(file_tail);
our $VERSION = '0.01';



my %file_stats;

sub file_tail {
  my $file = shift;
  my ($name, $path, $suffix) = fileparse($file);
  return unless (-f $file);
  return unless (-T $file);
  my $firstrun = 0;
  my $oldmoddate = 0;
  my $oldbytes;			# the old size, if any
  if (exists $file_stats{$file}) {
    $oldmoddate = $file_stats{$file}->[0];
    $oldbytes = $file_stats{$file}->[1];
  } else {
    $oldbytes = 0;
    $firstrun = 1;
  }
  my $bytes = -s $file;		# the new size
  my $moddate = (stat($file))[9];
  # update the hash
  $file_stats{$file} = [ $moddate, $bytes ];

  return if ($moddate == $oldmoddate); # nothing changed, so next!

  my $offset;
  if ($bytes > $oldbytes) { # the new size is bigger, so the offset is the 
    $offset = $oldbytes;    # old size
  } else {
    $offset = 0; # if the old size is bigger, it means the file was truncated
  }
  open (my $fh, '<', $file) or die "Houston, we have a problem: $!";
  if ($offset > 0) {
    seek($fh, $offset, 0);    # move the cursor, starting from the end
  }
  my @saythings;
  while (<$fh>) {
    chomp;
    next if m/^\s*$/;
    s/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/xxx.xxx.xxx.xxx/g;
    s/(\w+\@)[\w.-]+/$1hidden.domain/g;
    push @saythings, $_, "\n";
  }
  if ($firstrun) {
    if ($#saythings > 15) {
      my @newsaythings = splice(@saythings, -15);
      @saythings = @newsaythings;
    }
  }
  my $body =  join("", @saythings);
  if ($body) {
    $body .= " (" . $name . ")" ;
    return "$body";
  }
  close $fh;
}

1;
