# -*- mode: cperl -*-

package BirbaBot::Todo;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(todo_add todo_remove todo_rearrange);

our $VERSION = '0.01';

=head2 todo_add($dbname, $channel, $todo)

Add the string $todo to $dbname for the channel $channel. Return a
string telling what we did

=cut

sub todo_add {
  my ($dbname, $channel, $todo);
  return "Not implemented, yet"; 
}

=head2 todo_remove($dbname, $channel, $id)

Remove the field with id $id from $dbname for the channel $channel. Return a
string telling what we did.

=cut

sub todo_remove {
  my ($dbname, $channel, $id);
  return "Not implemented, yet"; 
}




=head2 todo_list($dbname, $channel)

List the values in $dbname for channel $channel. Return the todos.

=cut

sub todo_list {
  my ($dbname, $channel);
  return "Not implemented, yet"; 
}


=head2 todo_rearrange($dbname, $channel)

Rearrange the fields in $dbname for $channel, to get progressive ids.
Return the new list of todo.

=cut

sub todo_remove {
  my ($dbname, $channel);
  return "Not implemented, yet"; 
}




1;
