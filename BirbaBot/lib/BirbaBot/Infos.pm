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

our @EXPORT_OK = qw(kw_add kw_new kw_query kw_remove kw_list kw_find kw_show kw_delete_item karma_manage);

our $VERSION = '0.01';

sub kw_new {
  my ($dbh, $who, $key, $value) = @_;
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
  return $reply;
}

sub kw_add {
  my ($dbh, $who, $key, $value) = @_;

  my $check = $dbh->prepare('SELECT key FROM factoids WHERE key = ?');
  $check->execute($key);
  unless ($check->fetchrow_array()) {
    return kw_new($dbh, $who, $key, $value)
  }
  my $bar3check = $dbh->prepare('SELECT bar3 FROM factoids WHERE key = ?');
  $bar3check->execute($key);
  if ($bar3check->fetchrow_array()) {
    return "No more slots to add a new definition."
  }
  my $query = $dbh->prepare("UPDATE factoids SET bar2 = CASE WHEN bar2 IS NULL THEN ? WHEN bar2 IS NOT NULL THEN (SELECT bar2 FROM factoids where key = ?) END, bar3 = CASE WHEN bar2 IS NOT NULL AND bar3 IS NULL THEN ? WHEN bar2 IS NULL THEN (SELECT bar3 FROM factoids where key = ?) WHEN bar3 IS NOT NULL THEN (SELECT bar3 FROM factoids where key = ?) END WHERE key = ?;"); #bar2, bar3, key
  $query->execute($value, $key, $value, $key, $key, $key);
  return "Added $value to $key"
}

sub kw_remove {
  my ($dbh, $who, $key) = @_;
  my $del = $dbh->prepare("DELETE FROM factoids WHERE key=?;"); #key
  my $query = $dbh->prepare("SELECT key FROM factoids WHERE key=?;"); #key
  $query->execute($key);
  my $value = ($query->fetchrow_array());
  if (($value) && ($value eq $key)) { 
    $del->execute($key);
    return "I completely forgot $key";
  } else { 
    return "Sorry, dunno about $key"; 
  }
}

sub kw_delete_item {
  my ($dbh, $key, $position) = @_;
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
  return "I forgot that $key is $value";
}

sub kw_query {
  my ($dbh, $nick, $key) = @_;
  my $questionkey = $key . '?';
  my $query = $dbh->prepare("SELECT bar1,bar2,bar3 FROM factoids 
                             WHERE key = ?;");
  $query->execute($key);
  # here we get the results
  my @out;
  my $redirect;
  my $tag;
  my $message;
  my $message2;

  while (my @data = $query->fetchrow_array()) {
    foreach my $result (@data) {
      if ($result) {
	push @out, $result 
      }
    }
  }
  return unless @out;

  if (scalar @out == 1) {
    my @possibilities;
    if ($out[0] =~ m/\|\|/) {
      @possibilities= split (/\s*\|\|\s*/, $out[0]);
    }
    elsif ($out[0] =~ m/^\s*(<reply>)?\s*(.*)\((.+\|.+)\)\s*(.*)?$/i) {
      $tag = $1;
      $message = $2;
      $message2 = $4;
      my $possibilities_string = $3;
      @possibilities = split (/\|/, $possibilities_string);
    }
    elsif ($out[0] =~ m/^\s*(<action>)?\s*(.*)\((.+\|.+)\)\s*(.*)?$/i) {
      $tag = $1;
      $message = $2;
      $message2 = $4;
      my $possibilities_string = $3;
      @possibilities = split (/\|/, $possibilities_string);
    }
    if (scalar @possibilities > 1) {
      my $number = scalar @possibilities;
      my $random = int(rand($number));
      $out[0] = $tag . $message . $possibilities[$random] . " " . $message2;
    }
    while ($out[0] =~ m/^\s*(<reply>){1}\s*see\s+(.+)$/i) {
      $redirect = $2;
      if ("$key" eq "$redirect") {
	my $egg2 = "Congratulations $nick, you've just discovered egg #2! ";
	my $bad = "I foresee two possibilities. One, coming face to face with herself 30 years older would put her into shock and she'd simply pass out. Or two, the encounter could create a time paradox, the results of which could cause a chain reaction that would unravel the very fabric of the space time continuum, and destroy the entire universe! Granted, that's a worse case scenario. The destruction might in fact be very localized, limited to merely our own galaxy. [doc]";
	return "$egg2"."$bad";
      } else {
	my $queryn = $dbh->prepare("SELECT bar1 FROM factoids WHERE key=?;"); #key
	$queryn->execute($redirect);
	my @data = $queryn->fetchrow_array();
	# here we process
	return $out[0] = 'This is very bad and should not happen; failed redirection: please check the content of this fact.' unless @data;
	if (@data) {
	  $out[0] = $data[0];
	}
      }
    }
    my $reply = $out[0];
    $reply =~ s/\$(who|nick)/$nick/gi;
    $reply =~ s/^\s*<action>\s*/ACTION /i;
    $reply =~ s/^\s*<reply>\s*//i;
    return $reply;
  } else {
    return join(", or ", @out);
  }
}


sub kw_list {
  my ($dbh) = shift;


  my $query = $dbh->prepare("SELECT key FROM factoids;"); #key
  $query->execute();
  # here we get the results
  my @out;
  while (my @data = $query->fetchrow_array()) {
    foreach my $result (@data) {
      if ($result) {
        push @out, $result
      }
    }
  }
  if ((@out) && (scalar @out <= 50)) {
    my $output = "I know the following facts: " . join(", ", sort(@out));
    return $output;
  } elsif ((@out) && (scalar @out > 50)) {
    my @facts = @out[0..49];
    my $output = "I know too many facts to be all listed: " . join(", ", (sort @facts)) . "...";
    return $output;
  } else { return "Dunno about any fact; empty list." }
}

sub kw_find {
  my ($dbh, $arg) = @_;
  my $like = "\%$arg\%";


  my $query = $dbh->prepare("SELECT key FROM factoids WHERE key LIKE ? ;"); #key
  $query->execute($like);
  # here we get the results
  my @out;
  while (my @data = $query->fetchrow_array()) {
    foreach my $result (@data) {
      if ($result) {
        push @out, $result
      }
    }
  }
  print "info: resolving private kw_find query for argument \"$arg\"\n";
  if (@out) {
    my $maxlenght = 3000;
    my $outstring = join(", ", sort(@out));
    if (length($outstring) <= $maxlenght) {
      my $output = "I know the following facts: " . "$outstring";
	return $output;
    } elsif (length($outstring) > $maxlenght) {
      my $outstring_cut = substr($outstring, 0, $maxlenght) . " ...";
      my $output = "I know too many facts, here follow some of them: " . "$outstring_cut";
      return $output;
    }                                                                
  } else { return "Dunno about any matching fact; empty list." }
}

sub kw_show {
  my ($dbh, $arg) = @_;


  my $query = $dbh->prepare("SELECT bar1,bar2,bar3 FROM factoids WHERE key = ? ;"); #key
  $query->execute($arg);
  my @out;
  while (my @data = $query->fetchrow_array()) {
    foreach my $result (@data) {
      if ($result) {
        push @out, $result
      }
    }
  }

  
  if ((scalar @out) == 1) {
    my $output = "keyword \"$arg\" has been stored with the following value: bar1 = $out[0]";
    return $output;
  } elsif ((scalar @out) == 2) {
    my $output = "keyword \"$arg\" has been stored with the following values: bar1 is = $out[0] and bar2 is = $out[1]";
    return $output;
  } elsif ((scalar @out) == 3) {
    my $output = "keyword \"$arg\" has been stored with the following values: bar1 is = $out[0], bar2 is = $out[1] and bar3 = $out[2]";
    return $output;
  } else { 
    return "I am not aware of any fact named \"$arg\".";
  }
}

sub karma_manage {
  my ($dbh, $nick, $action) = @_;

  unless ($action) {
    my $query = $dbh->prepare('SELECT nick, level FROM karma WHERE nick = ?;');
    $query->execute($nick);
    my @reply;
    while (my @data = $query->fetchrow_array()) {
      # we assume there is only one row or we pick the latest
      @reply = @data;
    }

    # print "disconnected db";
    if (@reply) {
      return \@reply;
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

    return "Karma for $nick updated less then one minute ago";
  }
  
  my $updatevalue = $dbh->prepare('UPDATE karma SET level = ?,last = ? where nick = ?;');
  
  if ($action eq '++') {
    $level++;
  } elsif ($action eq '--') {
    $level--;
  }
  
  $updatevalue->execute($level, $currenttime, $nick);

  return "Karma for $nick is now $level";
}

1;
