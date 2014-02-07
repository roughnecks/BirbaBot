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

# delete non-supported facts
my $delete = $dbh->prepare('DELETE FROM factoids WHERE factoid_key LIKE \'cmd:%\' or factoid_value LIKE \'%$randnick%\' or factoid_key LIKE \'_default%\' or factoid_key LIKE \'#del# cmd:%\' or factoid_value=\'\' or factoid_value LIKE \'%#del#%\' or factoid_key LIKE \'%#del#%\';');
$delete->execute();

$dbh->disconnect;

print "Deletion finished.\n";
