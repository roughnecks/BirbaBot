# -*- mode: cperl -*-

# First, we create our base schema class, which inherits from DBIx::Class::Schema
package app::Schema;
use base qw/DBIx::Class::Schema/;

# By default this loads all the Result (Row) classes in the app::Schema::Result:: namespace, 
# and also any resultset classes in the app::Schema::ResultSet:: namespace.
__PACKAGE__->load_namespaces();

1;

