# -*- mode: cperl -*-

package BirbaBot::RSS;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw(
		    rss_add_new
		    rss_get_my_feeds
		    rss_delete_feed
		    rss_list
		    rss_give_latest
		    rss_clean_unused_feeds
		  );

our $VERSION = '0.01';

use XML::Feed;
use LWP::UserAgent;
use DBI;
use BirbaBot::Shorten;
use Data::Dumper;

my $ua = LWP::UserAgent->new(timeout => 10); # we can't wait too much
$ua->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.1.16) Gecko/20110929 Iceweasel/3.5.16 (like Firefox/3.5.16)');
$ua->show_progress(1);

my $bbold = "\x{0002}";
my $ebold = "\x{000F}";


=head2 add_new_rss($dbname, $feedname, $channel, $url)

This function adds a new feed to watch, taking the dbname, the
feedname, the channel to output and the url to watch.

=cut


sub rss_add_new {
  my ($dbname, $feedname, $channel, $url) = @_;

  # sanity check
  return 0 unless ($feedname =~ m/^\w+$/s);

  # then test if the $url is really an url and parsable
  my $rssfeed = XML::Feed->parse(URI->new($url))
    or return "$url doesn't look like an RSS";
  my $feedtitle = $rssfeed->title;
  return "$url doesn't look like an RSS" unless $feedtitle;

  # our queries
  my $add_to_rss_query = 'INSERT INTO rss VALUES (?, ?);'; # f_handle & url

  # f_handle, channel, active
  my $add_to_channels_query = 'INSERT INTO channels VALUES (?, ?);'; # f_handle & f_channel

  # connect
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');

  # do the 2 queries
  my $rssq = $dbh->prepare($add_to_rss_query);
  $rssq->execute($feedname, $url);

  my $chanq = $dbh->prepare($add_to_channels_query);
  $chanq->execute($feedname, $channel);

  # we should return the errors, but for now go without
  $dbh->disconnect;
  
  return "Added $feedtitle ($url) as $feedname";
}

=head2 rss_delete_feed($dbname, $feedname, $channel)

Stop to output the feeds $feedname on channel $channel, using $dbname
If the rss is not more watched, remove it from rss and feeds too.

=cut 

sub rss_delete_feed {
  my ($dbname, $feedname, $channel) = @_;
  my $reply;
  my $excode = 0;
  # connect
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  
  my $check_del = $dbh->prepare("SELECT * FROM channels WHERE f_handle = ? AND f_channel = ?;");
  $check_del->execute($feedname, $channel);
  unless ($check_del->fetchrow_array()) {
    return ("WTF, I'm not watching $feedname on $channel");
  }
  my $rss_del_query = "DELETE FROM channels WHERE f_handle = ? AND f_channel = ?;";
  my $rss_del = $dbh->prepare($rss_del_query);
  $rss_del->execute($feedname, $channel);
  if ($rss_del->err) {
    return (0, 0); # failure
  } else {
    $reply = "Stopped watching $feedname on $channel";
  }
  # now it's gone. Let's check if it's used.

  my $rss_check = $dbh->prepare("SELECT * FROM channels WHERE f_handle = ?;");
  $rss_check->execute($feedname);
  # unless the query returns something, let's drop the feed
  unless ($rss_check->fetchrow_array()) {
    print "$feedname is not watched anymore, removing from tables\n";
    my $clean_rss = $dbh->prepare("DELETE FROM rss WHERE f_handle = ?;");
    $clean_rss->execute($feedname);
    $reply .= " and purged";
    $excode = 1;
  }
  $dbh->disconnect;
  return ($reply, $excode);
}


sub rss_get_my_feeds {
  my ($dbname, $datadir) = @_;
  my $feeds = rss_fetch($dbname, $datadir);
  return dispatch_feeds($dbname, $feeds);
}


=head2 get_the_rss_to_fetch($dbname)

Query the db to see which urls we need to fetch

=cut


sub get_the_rss_to_fetch {
  my $dbname = shift;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $sth = $dbh->prepare('SELECT DISTINCT url, f_handle FROM rss;');
  $sth->execute();
  my %rsses;
  while (my @data = $sth->fetchrow_array()) {
    my $rss = $data[1];
    my $value = $data[0];
    $rsses{$rss} = $value;
  }
  $dbh->disconnect;
  return %rsses
}


=head2 rss_fetch($dbname, $datadir)

It fetches the feeds, dumps them in the db, and return an hash reference like this:
     
     {
       'lamerbot' => [
                       {
                         'link' => 'http://laltromondo.dynalias.net/gitweb/?p=lamerbot.git;a=commitdiff;h=d45c48b6303defb3977eaad68cbfbfd080b74c3a',
                         'desc' => 'new sql: date fixes', # uh? I can't see it
                         'author' => 'roughnecks <simcana@gmail.com>',
                         'title' => 'new sql: date fixes',
                         'content' => 'The commit message',
                       }
                     ]
     };
So the next step is to dispatch the feed to the relative channels

=cut


sub rss_fetch {
  my ($dbname, $datadir) = @_;
  $| = 1;
  # initialize the user agent
  my %output;
  my %urls = get_the_rss_to_fetch($dbname);

  # here we open the db;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", "", "");

  # and here we start the routineca
  foreach my $feedname (keys %urls) {
    my @outputfeed;
    unless ($feedname =~ m/^\w+$/s) {
      print "Warning: the name of the rss must be alphanumeric", 
        " + underscore only!\n";
      # no next!
      next;
    }
#    print "Fetching data for $feedname\n";
    my $destfile = File::Spec->catfile($datadir, $feedname);
    my $response;
    print "Mirroring ", $urls{$feedname}, "to  $destfile";
    eval { 
      $response = $ua->mirror($urls{$feedname}, $destfile);
    };
    print $@ if $@;
    next if $@;
    # now, as far as I understand, the "mirror" response doesn't return
    # the content, which is actually stored in the file.
    # So I guess we either do 'get' request, or we open the file
    if ($response->is_success) {
      my $btime = localtime();
      print "Parsing $destfile on $btime\n";
      my $rss;
      my @items;
      eval {
	$rss = XML::Feed->parse($destfile);
	@items = reverse $rss->entries;
      };
      if ($@) {
	print $@;
	next;
      };
      my %linksinrss;
      my $sth = 
        $dbh->prepare("INSERT INTO feeds VALUES (NULL, DATETIME('NOW'),  ?, ?, ?, ?, ?)");
      my %alreadyfetchedurls;
      my $existingquery = $dbh->prepare("SELECT url FROM feeds WHERE f_handle = ?");
      $existingquery->execute($feedname);
      while (my @presenturls = $existingquery->fetchrow_array()) {
	my $link = $presenturls[0];
#	print $link, " is present\n";
	$alreadyfetchedurls{$link} = 1;
      }
      #      print Dumper(\%alreadyfetchedurls);
      ## start looping over RSS
      foreach my $item (@items) {
	# avoid doing another loop, and save the link
	my $feed_item_link = $item->link;
	$linksinrss{$feed_item_link} = 1;
	if ($alreadyfetchedurls{$feed_item_link}) {
	  next
	};
	my $feed_item_title = $item->title;
	my $feed_item_author = $item->author;
	my $feed_item_content = $item->summary->body || $item->content->body;
	my $feed_item_tinyurl = BirbaBot::Shorten::make_tiny_url($feed_item_link);
	my $out_link;
	if ($feed_item_link eq $feed_item_tinyurl) {
	  $feed_item_tinyurl = undef;
	  $out_link = $feed_item_link;
	} else {
	  $out_link = $feed_item_tinyurl;
	}
	#strip the tags
	clean_up_and_trim_html_stuff(\$feed_item_title);
	clean_up_and_trim_html_stuff(\$feed_item_content);
        $sth->execute(
                      $feedname,
                      $feed_item_title,
                      $feed_item_author,
                      $feed_item_link,
                      $feed_item_tinyurl
		     );
        unless ($sth->err) {
          # here we push the new feed in a multidimensional hash
          push @outputfeed,
            {
	     title   => $feed_item_title,
             author  => $feed_item_author,
	     content => $feed_item_content,
             link    => $out_link,
	    };
        }
      }
      $output{$feedname} = \@outputfeed;
      my $endtime  = localtime();
      print "Parsing and insertions in $feedname finished on $endtime";
 #     print Dumper(\%linksinrss);
      print "Starting db cleaning...";
      my $syncdb = $dbh->prepare('SELECT id,url FROM feeds WHERE f_handle = ?;');
      my $cleandb = $dbh->prepare('DELETE FROM feeds WHERE id = ?');
      $syncdb->execute($feedname);
      while (my @urls_in_db =  $syncdb->fetchrow_array()) {
	my ($id, $url) = @urls_in_db;
	unless ($linksinrss{$url}) {
	  print "Removing $url from db of $feedname with id $id\n";
	  $cleandb->execute($id) ;
	}
      }
      my $ftime = localtime();
      print "Done on $ftime\n"
    }
  }
  $dbh->disconnect;
  print "RSS fetching and parsing done\n";
  return \%output;
}

=head2 dispatch_feeds($dbname, $hashref)

Take as argument the db name, and the output of rss_fetch.

Query the db to see where the the feeds should go, parse them and output a hash references with #channel => [news1, news2] pairs. 

=cut


sub dispatch_feeds {
  my ($dbname, $hashref) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  my $processed_feeds = process_feeds($hashref);
  my $sth = $dbh->prepare('SELECT f_channel FROM channels WHERE f_handle = ?');
  my %output;

  # for each $feedname provided by the rss processor, we find the
  # destinations. We return an hash with #channel => [$news1, $news2]
  # so the bot can loop over that and *finally* print the shit

  foreach my $feedname (keys %$processed_feeds) {
    $sth->execute($feedname);
    while (my @destinations = $sth->fetchrow_array()) {
      my $channel = $destinations[0];
      $output{$channel} = [] unless exists $output{$channel};
      my $stuff = $processed_feeds->{$feedname};
      foreach my $news (@$stuff) {
	push @{$output{$channel}}, $news;
#	print "To $channel: $channel :::", "$news", "\n";
      }
    }
  }
  $dbh->disconnect;
  return \%output;
}


sub process_feeds {
  my $hashref = shift;
  my %output;
  foreach my $feedname (keys %$hashref) {
    my @processed;
    my $feedsref = $hashref->{$feedname};
    my @feeds = splice(@$feedsref, 0, 5); # output just the last 5, OK?
    # now loop over the feeds and create the string
    while(@feeds) {
      my $news = shift(@feeds);
      print Dumper($news);
      my $string = $bbold . $feedname . "::" . $ebold . " ";
      if ($news->{'title'}) {
	$string .= $news->{'title'} . " || ";
      }
      if ($news->{content}) {
	if ($news->{title} eq $news->{content}) {
	  print "Not printing duplicated content in link and content";
	}
	else {
	  $string .= $news->{content};
	}
      }
      if ($news->{'author'}) {
	$string .= " (" . $news->{'author'} . ")";
      }
      if ($news->{'link'}) {
	$string .= "<${bbold}" . $news->{'link'} . "${ebold}>";
      }
      push @processed, $string;
    }
    $output{$feedname} = \@processed;
  }
  return \%output;
}

=head2 rss_give_latest($dbname, $feed)

Query the DB $dbname for the latest RSS feeds tagged $feed. Return an
array of replies. If $feed is not provided, just list the latest 5
feeds. If you need more, get a newsreader, ok?

=cut


sub rss_give_latest {
  my ($dbname, $feed) = @_;
  my @list;
  
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');

  # prepare the query
  my $query;
  if ($feed) {
    $query = $dbh->prepare("SELECT title, url, date, f_handle, tiny FROM feeds WHERE f_handle = ? ORDER BY id DESC LIMIT 5;");
    $query->execute($feed);
  } 
  else {
    $query = $dbh->prepare("SELECT title, url, date, f_handle, tiny FROM feeds ORDER BY id DESC LIMIT 5;");
    $query->execute;
  }
  
  # do it and store the string in @list;
  while (my @data = $query->fetchrow_array()) {
    my $url;
    if ($data[4]) {
      $url = $data[4];
    } else {
      $url = $data[1];
    }
    my $string = $data[0] . " " . $url . " " . "(" . $data[2] . " " . $data[3] .  ")";
    push @list, $string;
  }
  # disconnect
  $dbh->disconnect;
  return @list;
}

sub rss_list {
  my ($dbname, $channel) = @_;
  my @watched;
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  
  my $query = $dbh->prepare("SELECT rss.f_handle, rss.url FROM rss INNER JOIN channels ON rss.f_handle = channels.f_handle WHERE f_channel = ?;");
  $query->execute($channel);
  while (my @data = $query->fetchrow_array()) {
    my $reply = $bbold . $data[0] . $ebold . " (" . $data[1] . ")";
    push @watched, $reply;
  }
  $dbh->disconnect;
  print Dumper(\@watched);
  return join(" ", @watched);
}

sub rss_clean_unused_feeds {
  my ($dbname, $channels) = @_;
  my %joinchan;
  foreach my $chan (@$channels) {
    $joinchan{$chan} = 1;
  }
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname","","");
  $dbh->do('PRAGMA foreign_keys = ON;');
  my $query = $dbh->prepare('SELECT f_handle,f_channel FROM channels');
  $query->execute();
  my @to_delete;
  while (my @data = $query->fetchrow_array()) {
    my $feed = $data[0];
    my $channel = $data[1];
    unless (exists $joinchan{$channel}) {
      push @to_delete, [$feed, $channel];
    }
  }
  $dbh->disconnect;
  foreach my $delete (@to_delete) {
    print "Deleting ",  $delete->[0], " on ", $delete->[1], 
      " because we are not joining it\n";
    rss_delete_feed($dbname, $delete->[0], $delete->[1]);
  }
}

sub clean_up_and_trim_html_stuff {
  my $string = shift;
  # first, check for <br> or <p>
  $$string =~ s!<(br|p)\s*/\s*>! | !g;
  $$string =~ s!<.+?>!!g;
  my @chunks = split /\s+/, $$string;
  my $out = " ";
  while (@chunks && (length($out) < 300)) {
    $out .= shift(@chunks) . " "
  }
  $$string = $out . "...";
}


1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

BirbaBot - Perl extension for blah blah blah

=head1 SYNOPSIS

  use BirbaBot;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for BirbaBot, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

melmoth, E<lt>melmoth@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by melmoth

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
