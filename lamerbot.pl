#!/usr/bin/perl
# -*- mode: cperl -*-

# No copyright
# Written by Marco Pessotto a.k.a. MelmothX

# This code is free software; you may redistribute it
# and/or modify it under the same terms as Perl itself.

use strict;
use warnings;
use Data::Dumper;

my $config_file = $ARGV[0];

show_help() unless $config_file;

my $configuration = read_config($config_file);

print Dumper($configuration);

exit;

=head2 read_config

Read the configuration file, which should be passed on the command line, and return an hashref with key-value pairs for the bot config. 

=cut 

sub read_config {
  my $file = shift;
  my %config;
  show_help() unless (-f $file);
  open (my $fh, "<", $file) or die "Cannot read $file $!\n";
  while (<$fh>) {
    my $line = $_;
    # strip whitespace
    chomp $line;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next if ($line =~ m/^#/);
    if ($line =~ m/(\w+)\s*=\s*(.*)/) {
      my $key = $1;
      my $value = $2;
      $value =~ s/^"//;
      $value =~ s/"$//;
      $config{$1} = $2;
    }
  }
  close $fh;
  return \%config;
}

=head2 show_help

Well, show the help and exit

=cut


sub show_help {
  print <<HELP;

This script runs the bot. It takes a mandatory argument with the
configuration file. The configuration file have values like this:

nick = pippo_il_bot
server = irc.syrolnet.org

Blank lines are just ignored. Lines starting with # are ignored too.
Don't put comments on the same line of a key-value pair, OK?
(Otherwise the comment will become part of the value).

Good luck.

HELP
  exit 1;
}
