# -*- mode: cperl -*-

package BirbaBot;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(create_bot_db
		read_config
		override_defaults show_help);

our $VERSION = '0.01';

=head2 create_bot_db($dbname);

Create the bot database tables 

=cut

sub create_bot_db {
  my $dbname = shift;
  return 0 unless $dbname;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","") or 
    return 0;

  $dbh->do('PRAGMA foreign_keys = ON;');

  $dbh->do('CREATE TABLE IF NOT EXISTS rss (
            f_handle        VARCHAR(30) PRIMARY KEY NOT NULL,
            url             TEXT UNIQUE);');

  $dbh->do ('CREATE TABLE IF NOT EXISTS channels (
             f_handle        VARCHAR(30) NOT NULL,
             f_channel       VARCHAR(30) NOT NULL,
             CONSTRAINT f_handcha UNIQUE (f_handle,f_channel),
             FOREIGN KEY(f_handle) REFERENCES rss(f_handle));');

  $dbh->do('CREATE TABLE IF NOT EXISTS feeds (
            id                      INTEGER PRIMARY KEY,
            date                    DATETIME,
            f_handle                VARCHAR(30) NOT NULL,
            title                   VARCHAR(255),
            author                  VARCHAR(255),
            url                     TEXT UNIQUE NOT NULL,
            FOREIGN KEY(f_handle) REFERENCES rss(f_handle) ON DELETE CASCADE);');

  $dbh->do('CREATE TABLE IF NOT EXISTS factoids (
            id                      INTEGER PRIMARY KEY,
            nick                    VARCHAR(30),
            key                     VARCHAR(30) UNIQUE NOT NULL,
            bar1                    TEXT NOT NULL,
            bar2                    TEXT,
            bar3                    TEXT);');
  $dbh->disconnect;
  return 1;
}

=head2 read_config

Read the configuration file, which should be passed on the command
line, and return an hashref with key-value pairs for the bot config.

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
      if ($key && (defined $value)) {
	$config{$key} = $value;
      }
    }
  }
  close $fh;
  return \%config;
}

sub override_defaults {
  # here we modify the values via reference on the fly
  my ($default, $fromfile) = @_;
  foreach my $key (keys(%$default)) {
    if (exists $fromfile->{$key}) {
      $default->{$key} = $fromfile->{$key};
    }
  }
}


=head2 show_help

Well, show the help and exit

=cut



sub show_help {
  my $string = shift;
  print "$string\n" if $string;

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





# Preloaded methods go here.

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
