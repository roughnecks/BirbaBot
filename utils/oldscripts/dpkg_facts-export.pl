#!/usr/bin/perl
# -*- mode: cperl -*-

use warnings;
use strict;

use Data::Dumper qw(Dumper);
use DBI;
use Cwd;

my $cwd = getcwd();

# Prepare the connection's options to sqlite
my $dbname = "birba.db";
# Change the sqlite dbname as needed
### END Manual editable settings ###

my $dbh = DBI->connect("dbi:SQLite:dbname=$cwd/$dbname") or die $DBI::errstr;
$dbh->do('PRAGMA foreign_keys = ON;');
print "Succesfully connected to the sqlite database $dbname\n";

open (my $fh, "<", "dpkg_facts") or die $!;

while (my $line = <$fh>) {
  chomp($line);
  if ($line =~ m/^\s*(.+)\s,,,\s(.+)$/) {
    my $query = $dbh->prepare("INSERT INTO factoids (nick, key, bar1) VALUES (?, ?, ?);");
    $query->execute('dpkg', $1, $2);
  } else {print "Probably wrong factoid type: $line\n"}
}

close($fh);
