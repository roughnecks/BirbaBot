# -*- mode: cperl -*-

package BirbaBot::Infos;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(kw_add kw_new kw_query kw_remove);

our $VERSION = '0.01';

sub kw_new {
  my ($dbname, $who, $key, $value) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');

  my $query = $dbh->prepare("INSERT INTO factoids (nick, key, bar1) VALUES (?, ?, ?);"); #nick, key, value1
  $query->execute($who, $key, $value);
  my $reply;
  if ($query->err) {
    my $errorcode = $query->err;
    if ($errorcode ==  19) {
      $reply = "I couldn't insert $value, $key already present"
    } else {
      $reply = "Unknow db error, returned $errorcode"
    }
  } else {
    $reply = "Okki"
  }
  $dbh->disconnect;
  return $reply;
}

sub kw_add {
  my ($dbname, $who, $key, $value) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN ? WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = ?) END, bar3 = CASE WHEN bar2 IS NOT NULL AND bar3 IS NULL THEN ? WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = ?) WHEN bar3 IS NOT NULL THEN (SELECT bar3 FROM factoids where key = ?) END WHERE key = ?;"); #bar2, bar3, key
  $query->execute($value, $key, $value, $key, $key, $key);
  $dbh->disconnect;
  return "Added $value to $key"
}

sub kw_remove {
  my ($dbname, $who, $key, $password) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("DELETE FROM factoids WHERE key=?;"); #key
  $query->execute($key);
  $dbh->disconnect;
  return "Removed $key";
}

sub kw_query {
  my ($dbname, $key) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("SELECT bar1,bar2,bar3 FROM factoids WHERE key=?;"); #key
  $query->execute($key);
  # here we get the results
  my @out;

  while (my @data = $query->fetchrow_array()) {
    # here we process
    return "Dunno that" unless @data;
    foreach my $result (@data) {
      if ($result) {
	push @out, $result 
      }
    }
  }
  $dbh->disconnect;
  if (@out) { 
    return join(", or ", @out)
  } else {
    return 
  }
}

1;
