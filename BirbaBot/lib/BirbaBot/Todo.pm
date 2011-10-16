# -*- mode: cperl -*-

package BirbaBot::Todo;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(todo_add todo_remove todo_rearrange);

our $VERSION = '0.01';




1;
