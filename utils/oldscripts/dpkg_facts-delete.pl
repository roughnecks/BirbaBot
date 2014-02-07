#!/usr/bin/perl
# -*- mode: cperl -*-

use warnings;
use strict;

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

# delete non-supported facts
my $delete = $dbh->prepare('DELETE FROM factoids WHERE key LIKE \'cmd:%\' or bar1 LIKE \'%$randnick%\' or key LIKE \'_default%\' or key LIKE \'#del# cmd:%\' or bar1=\'\' or bar1 LIKE \'%#del#%\' or key LIKE \'%#del#%\';');
$delete->execute();

print "Deletion finished.\n";
$dbh->disconnect;

exit 1;
