#!/usr/bin/perl
# -*- mode: cperl -*-

use warnings;
use strict;

use Data::Dumper qw(Dumper);
use DBIx::Class;
use DBI;

# app::Schema is under utils/app/
use app::Schema;

# Prepare the connection handle
my $dsn = "dbi:mysql:infobot";
my $user = "infobot";
my $password = "dpkgdebby";

my $schema = app::Schema->connect( $dsn, $user, $password ) or die $DBI::errstr;

# Find all of the facts
my @all_factoids = $schema->resultset('Factoids')->all;

# Cycle through facts and get keys/values
foreach my $fact (@all_factoids) {
    print $fact->factoid_key, " = ", $fact->factoid_value, "\n";
}

