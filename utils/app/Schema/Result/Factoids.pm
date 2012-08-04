# -*- mode: cperl -*-

# Here we create each of the classes we want to load as specified in the app::Schema
package app::Schema::Result::Factoids;
use base qw/DBIx::Class::Core/;

# Select tables for the class(es)
__PACKAGE__->table('factoids');
# Add columns to the class(es)
__PACKAGE__->add_columns(qw/ factoid_key factoid_value /);

1;
