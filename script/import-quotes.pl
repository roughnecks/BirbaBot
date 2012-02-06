#!/usr/bin/perl
use warnings;
use strict;

use DBI;

my $dbname = $ARGV[0];
$dbname or die "Usage: $0 db.name\n";


open (my $fh, '<', "quotes.l_altro_mondo") or die "missing file quotes.l_altro_mondo";

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
my $query = $dbh->prepare('INSERT INTO quotes (id, chan, author, phrase) VALUES (NULL, ?, ?, ?);');

while (<$fh>) {
  my $line = $_;
  if ($line =~ m/^(\d+)\s+(.+?)\s(.+?)\s#l_altro_mondo\s(.+?)\s(.+)$/) {
    $query->execute("##laltromondo", $4, $5);
  } else {
    print "Ignored $line\n";
  }
}

$dbh->disconnect;

close $fh;


