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

  ### fixme
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare('DELETE FROM quotes WHERE id = ?;');
  $query->execute($string);
  $dbh->disconnect;
}

=head2 ircquote_rand($dbname, $where)

Get a random quote for channel $where

=cut

sub ircquote_rand {
  my ($dbname, $where) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare();
  $query->execute;
  $dbh->disconnect;
  return @_;
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
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $query = $dbh->prepare();
  $query->execute;
  $dbh->disconnect;
  return @_;
}


1;
