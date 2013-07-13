#!/usr/bin/perl
# -*- mode: cperl -*-

use warnings;
use strict;
use DBI;
use Cwd;

## EDIT these options to reflect your mysql setup
my $db = 'infobot';
my $user = 'infobot';
my $passw = 'infobot';
## STOP EDITING HERE


my $dbh = DBI->connect("dbi:mysql:$db","$user","$passw")
    or die "Connection Error: $DBI::errstr\n";

print "Succesfully connected to the mysql database $db\n";

# delete garbage (thanks skizzhg)
open (my $fh, "<", "birba-to-delete.txt") or die $!;

while (my $line = <$fh>) {
  chomp($line);
  next if ($line =~ m/^#.+$/);
  next if ($line =~ m/^\s*$/);
  if ($line =~ m/^\s*(.+)\s,,,\s(.+)$/) {
      my $query = $dbh->prepare("DELETE FROM factoids WHERE factoid_key=?;");
      $query->execute($1);
  } else {print "Probably wrong factoid type: $line\n"}
}

# delete non-supported facts
my $delete = $dbh->prepare('DELETE FROM factoids WHERE factoid_key LIKE \'cmd:%\' or factoid_value LIKE \'%$randnick%\' or factoid_key LIKE \'_default%\' or factoid_key LIKE \'#del# cmd:%\' or factoid_value=\'\' or factoid_value LIKE \'%#del#%\' or factoid_key LIKE \'%#del#%\';');
$delete->execute();

close($fh);
$dbh->disconnect;

print "Deletion finished.\n";
