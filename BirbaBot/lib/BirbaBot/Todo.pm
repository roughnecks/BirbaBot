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

our @EXPORT_OK = qw(todo_add todo_remove todo_list todo_rearrange);

our $VERSION = '0.01';

=head2 todo_add($dbname, $channel, $todo)

Add the string $todo to $dbname for the channel $channel. Return a
string telling what we did

=cut

sub todo_add {
  my ($dbname, $channel, $todo) = @_;
  print @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare("SELECT MAX(id) FROM todo WHERE chan = ?");
  $query->execute($channel);
  my $id = ($query->fetchrow_array())[0];
  $id++;
  my $insert = $dbh->prepare("INSERT INTO todo VALUES (?, ?, ?);");
  $insert->execute($id, $channel, $todo);
  $dbh->disconnect;
  return "Added $todo to the TODO list for $channel";
}

=head2 todo_remove($dbname, $channel, $id)

Remove the field with id $id from $dbname for the channel $channel. Return a
string telling what we did.

=cut

sub todo_remove {
  my ($dbname, $channel, $id) = @_;
  return unless ($dbname && $channel && $id);
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare("DELETE FROM todo WHERE chan = ? AND id = ?;");
  $query->execute($channel, $id);
  $dbh->disconnect;
  return "Deleted todo with id $id from $channel"; 
}




=head2 todo_list($dbname, $channel)

List the values in $dbname for channel $channel. Return the todos.

=cut

sub todo_list {
  my ($dbname, $channel) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare("SELECT id, todo FROM todo WHERE chan = ?");
  $query->execute($channel);
  my $reply;
  while (my @data = $query->fetchrow_array()) {
    $reply .= "(" .  $data[0] . ")" . " " . $data[1] . " ";
  }
  $dbh->disconnect;
  if ($reply) {
    return "Todo for $channel: $reply";
  } else {
    return "Nothing to do :-)"
  }
}


=head2 todo_rearrange($dbname, $channel)

Rearrange the fields in $dbname for $channel, to get progressive ids.
Return the new list of todo.

=cut

sub todo_rearrange {
  my ($dbname, $channel);
  return "Not implemented, yet"; 
}




1;
