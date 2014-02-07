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

my $schema = app::Schema->connect( $dsn, $user, $password ) or die $DBI::errstr;
print "Succesfully connected to the mysql database\n";

# Find all of the facts
my @all_factoids = $schema->resultset('Factoids')->all;

open (my $fh, ">>", "dpkg_facts") or die $!;

# Cycle through facts and get keys/values to be saved in the dpkg_facts file.
foreach my $fact (@all_factoids) {
my $key = $fact->factoid_key;
my $value = $fact->factoid_value;
my $line = "$key"." ,,, "."$value";

print $fh "$line\n"
}

close($fh)
