# -*- mode: cperl -*-

package BirbaBot::Infos;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(kw_add kw_query kw_remove);

our $VERSION = '0.01';

sub kw_add {
  return "Adding @_ not implemented"
}

sub kw_remove {
  return "Remove for @_ not implemented"
}

sub kw_query {
  return "Quering for @_ not implemented"
}

1;
