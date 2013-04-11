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

=head2 todo_add($dbh, $channel, $todo)

Add the string $todo to $dbh for the channel $channel. Return a
string telling what we did

=cut

sub todo_add {
  my ($dbh, $channel, $todo) = @_;

  my $query = $dbh->prepare("SELECT MAX(id) FROM todo WHERE chan = ?");
  $query->execute($channel);
  my $id = ($query->fetchrow_array())[0];
  $id++;
  my $insert = $dbh->prepare("INSERT INTO todo VALUES (?, ?, ?);");
  $insert->execute($id, $channel, $todo);

  return "Added $todo to the TODO list for $channel";
}

=head2 todo_remove($dbh, $channel, $id)

Remove the field with id $id from $dbh for the channel $channel. Return a
string telling what we did.

=cut

sub todo_remove {
  my ($dbh, $channel, $id) = @_;
  return unless ($dbh && $channel && $id);

  my $test = $dbh->prepare("SELECT id FROM todo WHERE chan = ? AND id = ?;");
  $test->execute($channel, $id);
  unless ($test->fetchrow_array()) {
    return "No todo to mark as done";
  }
  my $query = $dbh->prepare("DELETE FROM todo WHERE chan = ? AND id = ?;");
  $query->execute($channel, $id);
  my $reply = "Deleted todo with id $id from $channel"; 
  if ($query->err) {
    $reply = "Something went wrong. Or *you* are a lamer, or *I* am drunk"
  }

  return $reply
}




=head2 todo_list($dbh, $channel)

List the values in $dbh for channel $channel. Return the todos.

=cut

sub todo_list {
  my ($dbh, $channel) = @_;

  my $query = $dbh->prepare("SELECT id, todo FROM todo WHERE chan = ?");
  $query->execute($channel);
  my $reply;
  while (my @data = $query->fetchrow_array()) {
    $reply .= "(" .  $data[0] . ")" . " " . $data[1] . " ";
  }

  if ($reply) {
    return "Todo for $channel: $reply";
  } else {
    return "Nothing to do :-)"
  }
}


=head2 todo_rearrange($dbh, $channel)

Rearrange the fields in $dbh for $channel, to get progressive ids.
Return the new list of todo.

=cut

sub todo_rearrange {
  my ($dbh, $channel) = @_;
  my @new;

  # first, we extract all the fields 
  my $query = $dbh->prepare("SELECT todo FROM todo WHERE chan = ?");
  $query->execute($channel);
  while (my @data = $query->fetchrow_array()) {
    push @new, $data[0];
  }
  my $cleaning = $dbh->prepare("DELETE FROM todo WHERE chan = ?");
  $cleaning->execute($channel);

  my $insert = $dbh->prepare("INSERT INTO todo VALUES (?, ?, ?);");
  my $id = 1;
  while (@new) {
    my $todo = shift(@new);
    $insert->execute($id, $channel, $todo);
    $id++;
  }
  return todo_list($dbh, $channel);
}

1;
