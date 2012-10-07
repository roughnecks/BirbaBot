# -*- mode: cperl -*-

package BirbaBot::Notes;

use 5.010001;
use strict;
use warnings;
use DBI;
use Data::Dumper;
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(notes_add notes_give notes_pending anotes_pending notes_del anotes_del);

our $VERSION = '0.01';

=head2 notes_add($dbh, $from, $to, $message)

Add the string $todo to $dbh for the channel $channel. Return a
string telling what we did

=cut

sub notes_add {
  my ($dbh, $from, $to, $message) = @_;

  my $query = $dbh->prepare('INSERT INTO notes (date, sender, recipient, message) VALUES (?,?,?,?);'); #key
  my $date = localtime();
  $query->execute($date, $from, $to, $message);

  return "Message \"$message\" for $to sent from $from on $date: stored";
}

=head2 notes_give($dbh, $who)

Remove the field with id $id from $dbh for the channel $channel. Return a
string telling what we did.

=cut

sub notes_give {
  my ($dbh, $who) = @_;

  my $query = $dbh->prepare('SELECT sender,message,date FROM notes WHERE recipient = ?');
  my $delete = $dbh->prepare('DELETE FROM notes WHERE recipient = ?');
  $query->execute($who);
  my @out;
  while (my @data = $query->fetchrow_array()) {
    my ($sender, $message, $date) = @data;
    push @out, "On $date $sender left a note to you: $message";
  }
  if (@out) {
    $delete->execute($who);
  }

  return @out; 
}

sub notes_pending {
  my ($dbh, $who) = @_;

  my $query = $dbh->prepare('SELECT recipient FROM notes WHERE sender = ?');
  $query->execute($who);
  my @out;
  while (my $data = $query->fetchrow_array()) {
    push @out, $data;
  }

  if (@out) {
    my $response = join (", ", @out);
    return "Some notes are awaiting to be sent to: $response."
  } else { return "No notes pending from $who." }
}

sub notes_del {
  my ($dbh, $sender, $rcpt) = @_;

  return "Wrong arguments" unless ($sender && $rcpt);
  my $delete = 
    $dbh->prepare('DELETE FROM notes WHERE recipient = ? AND sender = ?');
  my $query = 
    $dbh->prepare('SELECT recipient FROM notes WHERE recipient = ? AND sender = ?');
  $query->execute($rcpt, $sender);
  # if there something in the query, means that there's something to delete
  if (my @data = $query->fetchrow_array()) {
    $delete->execute($rcpt, $sender);

    return "Succesfully deleted pending notes to: $rcpt."
  } else {
    return "No pending notes to $rcpt found."
  }
}


sub anotes_pending {
  my ($dbh, $who) = @_;

  my $query = $dbh->prepare('SELECT sender FROM notes');
  $query->execute;
  my @out;
  while (my $data = $query->fetchrow_array()) {
    push @out, $data;
  }

  if (@out) {
    my $response = join (", ", @out);
    return "Some notes are awaiting to be sent from: $response."
  } else { return "No notes pending." }
}

sub anotes_del {
  my ($dbh, $sender) = @_;

  return "Wrong arguments" unless ($sender);
  my $delete = 
    $dbh->prepare('DELETE FROM notes WHERE sender = ?');
  my $query = 
    $dbh->prepare('SELECT recipient FROM notes WHERE sender = ?');
  $query->execute($sender);
  # if there something in the query, means that there's something to delete
  if (my @data = $query->fetchrow_array()) {
    $delete->execute($sender);

    return "Succesfully deleted pending notes by: $sender."
  } else {
    return "No pending notes by $sender found."
  }
}


1;
