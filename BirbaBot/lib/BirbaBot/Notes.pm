# -*- mode: cperl -*-

package BirbaBot::Notes;

use 5.010001;
use strict;
use warnings;
use DBI;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(notes_add notes_give);

our $VERSION = '0.01';

=head2 notes_add($dbname, $from, $to, $message)

Add the string $todo to $dbname for the channel $channel. Return a
string telling what we did

=cut

sub notes_add {
  my ($dbname, $from, $to, $message) = @_;
  return "Not implemented, yet";
}

=head2 notes_give($dbname, $who)

Remove the field with id $id from $dbname for the channel $channel. Return a
string telling what we did.

=cut

sub notes_give {
  my ($dbname, $who) = @_;
  return "Not implemented, yet"; 
}


1;
