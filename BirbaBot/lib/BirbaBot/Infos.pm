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
  my $query = $dbh->prepare("INSERT INTO factoids (nick, key, bar1) VALUES ('?', '?', '?');"); #nick, key, value1
  $query->execute($key, $value, $who);
  $db->disconnect;
  return "Adding @_ not implemented"
}

sub kw_add {
  my ($dbname, $who, $key, $value) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN '?' WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = '?') END, bar3 = CASE WHEN bar2 IS NOT NULL AND bar3 IS NULL THEN '?' WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = '?') WHEN bar3 IS NOT NULL THEN (SELECT bar3 FROM factoids where key = '?') END WHERE key='test';"); #bar2, bar3, key
  $query->execute($key, $value, $who);
  $db->disconnect;
  return "Adding @_ not implemented"
}

sub kw_remove {
  my ($dbname, $who, $key, $password) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("DELETE FROM factoids WHERE key='?';"); #key
  $query->execute($key, $value, $who);
  $db->disconnect;
  return "Remove for @_ not implemented"
}

sub kw_query {
  my ($dbname, $who, $key, $value) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("SELECT bar1,bar2,bar3 FROM factoids WHERE key='?';"); #key
  $query->execute($key, $value, $who);
  # here we get the results
  while (my @data = $query->fetchrow_array()) {
    # here we process
    print @data;
  }
  $db->disconnect;
  return "Quering for @_ not implemented"
}

1;
