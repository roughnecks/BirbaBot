# -*- mode: cperl -*-

package BirbaBot::Quotes;

use 5.010001;
use strict;
use warnings;
use DBI;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(ircquote_add 
		    ircquote_del 
		    ircquote_rand 
		    ircquote_last 
		    ircquote_find
		    ircquote_num
		  );

our $VERSION = '0.01';

=head2 ircquote_add($dbname, $who, $where, $string)

Add the quote $string to the quote db, with author $who and channel $where

=cut

sub ircquote_add {
  my ($dbname, $who, $where, $string) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare('INSERT INTO quotes (id, chan, author, phrase) VALUES (NULL, ?, ?, ?);');
  $query->execute($where, $who, $string);
  my $errorcode = $query->err;
  $dbh->disconnect;
  if ($errorcode) {
    return "DB transation ended with error $errorcode";
  } else {
    return "Quote added";
  }
}

=head2 ircquote_del($dbname, $who, $where, $string)

Delete the quote with id $string if the author and $who match.

=cut

sub ircquote_del {
  my ($dbname, $who, $where, $string) = @_;
  my $id;
  my $reply;
  if ($string =~ m/([0-9]+)/) {
    $id = $1;
  } else {
    return "Illegal characters in deletion command";
  }
  
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $checkquery = $dbh->prepare('SELECT author,phrase FROM quotes WHERE id = ?');
  my $delquery = $dbh->prepare('DELETE FROM quotes WHERE id = ?;');

  $checkquery->execute($id);
  my ($author) = $checkquery->fetchrow_array();

  if ($author) {
    if ($author eq $who) { 
      $delquery->execute($id);
      my $error = $delquery->err;
      if ($error) {
	$reply = "$error while deletin";
      } else {
	$reply = "Quote with id $id deleted";
      }
    } else {
      $reply = "The quote is not yours to delete";
    }
  } else {
    $reply = "No such quote"
  }
  $dbh->disconnect;
  return $reply;
}

=head2 ircquote_rand($dbname, $where)

Get a random quote for channel $where

=cut

sub ircquote_rand {
  my ($dbname, $where) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $queryids = $dbh->prepare('SELECT id FROM quotes WHERE chan = ?;');
  $queryids->execute($where);
  my @quotesid;
  while (my @ids = $queryids->fetchrow_array()) {
    push @quotesid, $ids[0];
  }
  $dbh->disconnect;
  return "No quotes!" unless @quotesid;

  my $total = 
  my $random = int(rand(scalar @quotesid));
  print "Picked random quote with id $random\n";
  my $choosen = $quotesid[$random];
  return ircquote_num($dbname, $choosen);
}

=head2 ircquote_last($dbname, $where);

Get the latest quote for channel $where

=cut

sub ircquote_last {
  my ($dbname, $who, $where, $string) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare();
  $query->execute;
  $dbh->disconnect;
  return @_;
}


=head2 ircquote_find($dbname, $where, $string);

Find a quote with $string inside for channel $where

=cut

sub ircquote_find {
  my ($dbname, $where, $string) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare();
  $query->execute;
  $dbh->disconnect;
  return @_;
}

=head2 ircquote_num($dbname, $num);

Add the quote $string to the quote db, with author $who and channel $where

=cut

sub ircquote_num {
  my ($dbname, $num) = @_;
  my $reply;
  if ($num =~ m/(\d+)/) {
    $num = $1;
  } else {
    return "Invalid character $num for quotes"
  }
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare('SELECT author,phrase FROM quotes WHERE id = ?');
  $query->execute($num);
  my ($author, $phrase) = $query->fetchrow_array();
  my $error = $query->err;
  if ($error) {
    $reply = "Error $error while fetching id $num"
  } else {
    if ($phrase and $author) {
      $reply = "[$num] $phrase (added by $author)";
    } else {
      $reply = "No such quote";
    }
  }
  $dbh->disconnect;
  return $reply;
}

1;
