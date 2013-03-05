#!/usr/bin/perl
# -*- mode: cperl -*-

use warnings;
use strict;

use Data::Dumper qw(Dumper);
use DBIx::Class;
use DBI;
use Cwd;

# app::Schema is under utils/app/
use app::Schema;

my $cwd = getcwd();

### START Manual editable settings ###
# Prepare the connection's options to mysql
my $dsn = "dbi:mysql:infobot";
# Change "infobot" to your mysql db name
my $user = "infobot";
# mysql user
my $password = "dpkgdebby";
# mysql user's password

# Prepare the connection's options to sqlite
my $dbname = "birba.db";
# Change the sqlite dbname as needed
### END Manual editable settings ###

my $schema = app::Schema->connect( $dsn, $user, $password ) or die $DBI::errstr;
print "Succesfully connected to the mysql database\n";

my $dbh = DBI->connect("dbi:SQLite:dbname=$cwd/$dbname") or die $DBI::errstr;
$dbh->do('PRAGMA foreign_keys = ON;');
print "Succesfully connected to the sqlite database $dbname\n";

# Find all of the facts
my @all_factoids = $schema->resultset('Factoids')->all;
print "Starting importer..\n";

# Cycle through facts and get keys/values to be imported in the sqlited db
foreach my $fact (@all_factoids) {
my $key = $fact->factoid_key;
my $value = $fact->factoid_value;

my $query = $dbh->prepare("INSERT INTO factoids (nick, key, bar1) VALUES (?, ?, ?);");
$query->execute('dpkg', $key, $value);
}
print "Importing finished.\n";

print "Starting deletion..\n";
# delete non-supported facts
my $delete = $dbh->prepare('DELETE FROM factoids WHERE key LIKE \'cmd:%\' or bar1 LIKE \'%$randnick%\' or key LIKE \'_default%\';');
$delete->execute();
print "Deletion finished.\n";

$dbh->disconnect;
