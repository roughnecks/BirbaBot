# -*- mode: cperl -*-

package BirbaBot::Quotes;

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

our @EXPORT_OK = qw(ircquote_add 
		    ircquote_del 
		    ircquote_rand 
		    ircquote_last 
		    ircquote_find
		    ircquote_num
		  );

our $VERSION = '0.01';

=head2 ircquote_add($dbh, $who, $where, $string)

Add the quote $string to the quote db, with author $who and channel $where

=cut

sub ircquote_add {
  my ($dbh, $who, $where, $string) = @_;

  my $query = $dbh->prepare('INSERT INTO quotes (id, chan, author, phrase) VALUES (NULL, ?, ?, ?);');
  $query->execute($where, $who, $string);
  my $idquery = $dbh->prepare('SELECT id FROM quotes WHERE chan = ? ORDER BY id DESC LIMIT 1;');
  $idquery->execute($where);
  my $id = $idquery->fetchrow_array();
  my $errorcode = $query->err;

  if ($errorcode) {
    return "DB transation ended with error $errorcode";
  } else {
    return "Quote \#$id added";
  }
}

=head2 ircquote_del($dbh, $who, $where, $string)

Delete the quote with id $string if the author and $who match.

=cut

sub ircquote_del {
  my ($dbh, $who, $where, $string) = @_;
  my $id;
  my $reply;
  if ($string =~ m/([0-9]+)/) {
    $id = $1;
  } else {
    return "Illegal characters in deletion command";
  }
  

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

  return $reply;
}

=head2 ircquote_rand($dbh, $where)

Get a random quote for channel $where

=cut

sub ircquote_rand {
  my ($dbh, $where) = @_;

  my $queryids = $dbh->prepare('SELECT id FROM quotes WHERE chan = ?;');
  $queryids->execute($where);
  my @quotesid;
  while (my @ids = $queryids->fetchrow_array()) {
    push @quotesid, $ids[0];
  }

  return "No quotes!" unless @quotesid;

  my $total = 
  my $random = int(rand(scalar @quotesid));
  print "Picked random quote with id $random\n";
  my $choosen = $quotesid[$random];
  return ircquote_num($dbh, $choosen, $where);
}

=head2 ircquote_last($dbh, $where);

Get the latest quote for channel $where

=cut

sub ircquote_last {
  my ($dbh, $where) = @_;
  my $reply;

  my $query = $dbh->prepare('SELECT id,author,phrase FROM quotes WHERE chan = ? ORDER BY id DESC LIMIT 1;');
  $query->execute($where);
  my ($id, $author, $phrase) = $query->fetchrow_array();
  print "$id, $author, $phrase\n";
  if ($phrase) {
    $author =~ s/\!.+$//;
    $reply =  "[$id] $phrase (added by $author)"
  } else {
    $reply = "No quotes!";
  }

  return $reply;
}


=head2 ircquote_find($dbh, $where, $string);

Find a quote with $string inside for channel $where

=cut

sub ircquote_find {
  my ($dbh, $where, $string) = @_;
  my $reply;
  { use locale;
    $string =~ s/\W/%/g;
    $string = '%' . $string . '%';
    $string =~ s/%%+/%/g;
    print "Using $string for query";
  }

  my $query = $dbh->prepare('SELECT id,phrase FROM quotes WHERE chan = ? AND phrase LIKE ?;');
  $query->execute($where, $string);
  # find all
  my @output;
  while (my @quotes = $query->fetchrow_array()) {
    
    push @output, [$quotes[0], $quotes[1] ];
  }

#  print Dumper(\@output);
  return "No quotes!" unless $output[0]->[1];
  $reply = '[' . $output[0]->[0] . '] ' . $output[0]->[1] . ". ";
  print Dumper(shift @output);
  $reply .= "Other quotes: " if @output;
  while (@output) {
    my $quote = shift(@output);
    $reply .= "[" . $quote->[0] . "] ";
  }
  return $reply;
}

=head2 ircquote_num($dbh, $num);

Add the quote $string to the quote db, with author $who and channel $where

=cut

sub ircquote_num {
  my ($dbh, $num, $where) = @_;
  #  print Dumper(\@_);
  my $reply;
  $num = $_[1];
  if ($num =~ m/(\d+)/) {
    $num = $1;
  } else {
    return "Invalid character $num for quotes"
  }

  my $query = $dbh->prepare('SELECT author,phrase FROM quotes WHERE id = ? and chan = ?');
  $query->execute($num, $where);
  my ($author, $phrase) = $query->fetchrow_array();
  my $error = $query->err;
  if ($error) {
    $reply = "Error $error while fetching id $num"
  } else {
    if ($phrase and $author) {
      $author =~ s/\!.+$//;
      $reply = "[$num] $phrase (added by $author)";
    } else {
      $reply = "No such quote";
    }
  }

  return $reply;
}

1;
