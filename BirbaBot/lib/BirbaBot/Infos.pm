# -*- mode: cperl -*-

package BirbaBot::Infos;

use 5.010001;
use strict;
use warnings;
use DBI;
use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(kw_add kw_new kw_query kw_remove kw_list kw_find kw_delete_item karma_manage);

our $VERSION = '0.01';

sub kw_new {
  my ($dbname, $who, $key, $value) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');

  my $query = $dbh->prepare("INSERT INTO factoids (nick, key, bar1) VALUES (?, ?, ?);"); #nick, key, value1
  $query->execute($who, $key, $value);
  my $reply;
  if ($query->err) {
    my $errorcode = $query->err;
    if ($errorcode ==  19) {
      $reply = "I couldn't insert $value, $key already present"
    } else {
      $reply = "Unknow db error, returned $errorcode"
    }
  } else {
    $reply = "Okki"
  }
  $dbh->disconnect;
  return $reply;
}

sub kw_add {
  my ($dbname, $who, $key, $value) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN ? WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = ?) END, bar3 = CASE WHEN bar2 IS NOT NULL AND bar3 IS NULL THEN ? WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = ?) WHEN bar3 IS NOT NULL THEN (SELECT bar3 FROM factoids where key = ?) END WHERE key = ?;"); #bar2, bar3, key
  $query->execute($value, $key, $value, $key, $key, $key);
  $dbh->disconnect;
  return "Added $value to $key"
}

sub kw_remove {
  my ($dbname, $who, $key) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $del = $dbh->prepare("DELETE FROM factoids WHERE key=?;"); #key
  my $query = $dbh->prepare("SELECT key FROM factoids WHERE key=?;"); #key
  $query->execute($key);
  my $value = ($query->fetchrow_array());
  if ($value eq $key) { 
    $del->execute($key);
    $dbh->disconnect;
    return "I completely forgot $key";
  } else { 
    return "Sorry, dunno about $key"; 
    $dbh->disconnect;
  }
}

sub kw_delete_item {
  my ($dbname, $key, $position) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $check;
  if ($position == 2) {
    $check = $dbh->prepare("SELECT bar2 FROM factoids WHERE key = ? ;");
  } elsif ($position == 3) {
    $check = $dbh->prepare("SELECT bar3 FROM factoids WHERE key = ? ;");
  }
  $check->execute($key);
  my $value = ($check->fetchrow_array())[0];
  return "I don't have any definition of $key on the $position slot" unless $value;

  my $query;
  if ($position == 2) {
    $query = $dbh->prepare("UPDATE factoids SET bar2 = NULL WHERE key = ? ;");
  } elsif ($position == 3) {
    $query = $dbh->prepare("UPDATE factoids SET bar3 = NULL WHERE key = ? ;");
  }
  $query->execute($key);
  $dbh->disconnect;
  return "I forgot that $key is $value";
}

sub kw_query {
  my ($dbname, $key) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("SELECT bar1,bar2,bar3 FROM factoids WHERE key=?;"); #key
  $query->execute($key);
  # here we get the results
  my @out;
  my $redirect;

  while (my @data = $query->fetchrow_array()) {
    # here we process
    return "Dunno that" unless @data;
    foreach my $result (@data) {
      if ($result) {
	push @out, $result 
      }
    }
  }
  
  while ($out[0] =~ m/^\s*(<reply>)?\s*see\s+(.+)$/i) {
    $redirect = $2;
    my $queryn = $dbh->prepare("SELECT bar1 FROM factoids WHERE key=?;"); #key
    $queryn->execute($redirect);
    while (my @data = $queryn->fetchrow_array()) {
      # here we process
      return unless @data;
      if (@data) {
	$out[0] = $data[0]
      }
    }
  }
  $dbh->disconnect;
  if (scalar @out == 1) {
    if ($out[0] =~ m/^\s*<reply>\s*(.+)$/i) {
      my $reply = $1;
      return "$reply"
    } else { return "$out[0]" }
  } elsif (scalar @out > 1) {
    return join(", or ", @out)
  } else { return }
}

sub kw_list {
  my ($dbname) = shift;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("SELECT key FROM factoids;"); #key
  $query->execute();
  # here we get the results
  my @out;
  while (my @data = $query->fetchrow_array()) {
    push @out, $data[0]
  }
  $dbh->disconnect;
  if (@out) {
    my $output = "I know the following facts: " . join(", ", sort(@out));
    return $output;
  } else { return "Dunno about any fact; empty list." }
}

sub kw_find {
  my ($dbname, $arg) = @_;
  my $like = "\%$arg\%";
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare("SELECT key FROM factoids WHERE key LIKE ? ;"); #key
  $query->execute($like);
  # here we get the results
  my @out;
  while (my @data = $query->fetchrow_array()) {
    push @out, $data[0]
  }
  $dbh->disconnect;
  if (@out) {
    my $output = "I know the following facts: " . join(", ", sort(@out));
    return $output;
  } else { return "Dunno about any fact; empty list." }
}

sub karma_manage {
  my ($dbname, $nick, $action) = @_;
  print "arguments for karma_manage: ", join(':', @_), "\n";
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  unless ($nick) {
    my @reply;
    my $query = $dbh->prepare('SELECT nick, level FROM karma');
    $query->execute();
    while (my @data = $query->fetchrow_array()) {
      push @reply, $data[0] . " => " . $data[1];
    }
    $dbh->disconnect;
    print "disconnected db";
    return join(", ", @reply);
  }
  unless ($action) {
    my $query = $dbh->prepare('SELECT level FROM karma WHERE nick = ?;');
    $query->execute($nick);
    my $reply ;
    while (my @data = $query->fetchrow_array()) {
      $reply = $nick . " has karma " . $data[0];
    }
    $dbh->disconnect;
    print "disconnected db";
    if ($reply) {
      return $reply;
    } else {
      return "No karma for $nick";
    }
  }

  my $oldkarma = $dbh->prepare('SELECT nick,level,last FROM karma WHERE nick = ?;');
  $oldkarma->execute($nick);
  my ($queriednick, $level, $lastupdate)  = $oldkarma->fetchrow_array();
  $oldkarma->finish();

  unless($queriednick) {
    my $insert = $dbh->prepare('INSERT INTO karma (nick, last, level) VALUES ( ?, ?, ?);');
    $insert->execute($nick, 0, 0);
    $level = 0;
    $lastupdate = 0;
  }

  my $currenttime = time();
  if (($currenttime - $lastupdate) < 60) {
    $dbh->disconnect;
    return "Karma for $nick updated less then one minute ago";
  }
  
  my $updatevalue = $dbh->prepare('UPDATE karma SET level = ?,last = ? where nick = ?;');
  
  if ($action eq '++') {
    $level++;
  } elsif ($action eq '--') {
    $level--;
  }
  
  $updatevalue->execute($level, $currenttime, $nick);
  $dbh->disconnect;
  return "Karma for $nick is now $level";
}

1;
