#!/usr/bin/perl
# -*- mode: cperl -*-

use warnings;
use strict;

use SQL::Translator;

my $file = "/home/lab/clones/birbabot/utils/factoids.sql";

my $translator          = SQL::Translator->new(
    # Print debug info
    debug               => 1,
    # Print Parse::RecDescent trace
    trace               => 0,
    # Don't include comments in output
    no_comments         => 0,
    # Print name mutations, conflicts
    show_warnings       => 1,
    # Add "drop table" statements
    add_drop_table      => 1,
    # to quote or not to quote, thats the question
    quote_table_names     => 1,
    quote_field_names     => 1,
    # Validate schema object
    validate            => 1,
    # Make all table names CAPS in producers which support this option
    format_table_name   => sub {my $tablename = shift; return uc($tablename)},
             # Null-op formatting, only here for documentation's sake
             format_package_name => sub {return shift},
             format_fk_name      => sub {return shift},
             format_pk_name      => sub {return shift},
         );

         my $output     = $translator->translate(
             from       => 'MySQL',
             to         => 'SQLite',
             # Or an arrayref of filenames, i.e. [ $file1, $file2, $file3 ]
             filename   => $file,
         ) or die $translator->error;

         print $output;
