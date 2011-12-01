# -*- mode: cperl -*-

package BirbaBot::Quotes;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(ircquote_add 
		    ircquote_del 
		    ircquote_rand 
		    ircquote_last 
		    ircquote_find
		    ircquote_num
		  );

our $VERSION = '0.01';

=head2 ircquote_add($who, $where, $string)

Add the quote $string to the quote db, with author $who and channel $where

=cut

sub ircquote_add {
  my ($who, $where, $string) = @_;
  return @_;
}

=head2 ircquote_del($who, $where, $string)

Delete the quote with id $string if the author and $who match.

=cut

sub ircquote_del {
  my ($who, $where, $string) = @_;
  return @_;
}

=head2 ircquote_rand($where)

Get a random quote for channel $where

=cut

sub ircquote_rand {
  my ($where) = @_;
  return @_;
}

=head2 ircquote_last($where);

Get the latest quote for channel $where

=cut

sub ircquote_last {
  my ($who, $where, $string) = @_;
  return @_;
}


=head2 ircquote_find($where, $string);

Find a quote with $string inside for channel $where

=cut

sub ircquote_find {
  my ($where, $string) = @_;
  return @_;
}

=head2 ircquote_num($num);

Add the quote $string to the quote db, with author $who and channel $where

=cut

sub ircquote_num {
  my ($num) = @_;
  return @_;
}


1;
