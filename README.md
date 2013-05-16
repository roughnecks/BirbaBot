BirbaBot, a POE Powered IRC Bot
===============================

![birbabot](https://raw.github.com/roughnecks/BirbaBot/master/files/birba.jpg)

About
-----

BirbaBot is a perl (ro)bot meant to be used in Internet Relay Chats (IRC): it's built upon the POE::IRC Framework and features many useful plugins, like RSS Feeds Management, Channel Quotes and Factoids, various Search Engines tools (like Google, bash.org and the Urban Dictionary) and so on.. BirbaBot is free code and this means you can freely grab a copy of it by using git to clone the online repository or downloading the tarball, which can always be found in the Downloads section of http://laltromondo.dynalias.net, as soon as a new release is available.

The resources required by the bot are moderately low: from our extensive testing, the bot can operate successfully with less than 50MB of RAM.


Installation
------------

### Required perl modules

    Debian                                 CPAN
    ------------------------------------------------------------------
    libpoe-component-irc-perl              POE::Component::IRC | POE::Component::IRC::Common
    libpoe-component-sslify-perl           POE::Component::SSLify
    libxml-rss-perl                        XML::RSS::LibXML
    libwww-perl                            LWP
    libcrypt-ssleay-perl                   Net::SSLeay
    libdbd-sqlite3-perl                    DBD::SQLite
    libgeo-ip-perl                         Geo::IP
    geoip-database                         
    libpoe-component-client-dns-perl       POE::Component::Client::DNS
    libxml-feed-perl                       XML::Feed
    libjson-any-perl                       JSON::Any
    liburi-find-perl                       URI::Find
    libyaml-perl                           YAML::Any
    libhtml-strip-perl			   HTML::Strip
    libsocket6-perl                        Socket6	## with perl >= 5.14 this module is not needed
    ------------------------------------------------------------------

Copy files/example.conf to some_file.conf in the bot root directory and modify it.

    cp files/example.conf bot.conf ; nano bot.conf

If you don't need console output start the bot with:

    ./restart.bot.sh bot.conf ## <<< This one also provides logging function

If you would like to see output in console window, start the bot with:

    ./birbabot.pl bot.conf

If you want to check if the bot crashed/stopped and reload it automatically use "restart.bot.sh" with cron;

* cron example:


    5,20,35,50 * * * * /home/user/birbabot/restart.bot.sh /home/user/birbabot/bot.conf


Commands
--------

To execute a command, prefix it with the "botprefix" you chose in the configuration file - defaul prefix is "@" ( at sign ).

Start asking for the online help with:

    @help

continue asking for the single command help with:

    @help <command>

## Commands List

anotes, bash, choose, deb, debsearch, done, free, g, geoip, gi, gv, imdb, isdown, karma, kw, lookup, math, meteo, note, notes, pull, quote, remind, restart, rss, seen, slap, todo, uptime, urban, version, wikiz

## Complex Commands Help

* Most of the commands require just an argument, or none - In this manual, only the most complex commands will be shown.

### @help imdb

"Query the Internet Movie Database (If you want to specify a year, put it at the end). Alternatively, takes one argument, an id or link, to fetch more data."

* Basic Usage: perform a simple search with keywords

@imdb terminator

    The Terminator, 1984, directed by James Cameron. Genre: Action, Sci-Fi. Rating:
    8.1. http://imdb.com/title/tt0088247 || Terminator 2: Judgment Day, 1991, directed
    by James Cameron. Genre: Action, Sci-Fi, Thriller. Rating: 8.6.
    http://imdb.com/title/tt0103064 || Terminator 3: Rise of the Machines, 2003,      
    directed by Jonathan Mostow. Genre: Action, Sci-Fi, Thriller. Rating: 6.5.        
    http://imdb.com/title/tt0181852

* Advanced Usage: perform a search by id or link

@imdb tt0088247

@imdb http://imdb.com/title/tt0088247

    The Terminator, 1984, directed by James Cameron, with Arnold Schwarzenegger, Linda
    Hamilton, Michael Biehn, Paul Winfield. Genre: Action, Sci-Fi. Rating: 8.1. A
    human-looking, apparently unstoppable cyborg is sent from the future to kill Sarah
    Connor; Kyle Reese is sent to stop it.


### @help kw

"Notice(Birba): (kw new|add <foo is bar | "foo is bar" is yes, probably foo is bar> | forget <foo> | delete <foo 2/3> | list | show <foo> | find <foo>) - (<!>key) - (key > <nick>) - (key >> <nick>) -- Manage the keywords: new/add, forget, delete, list, find, spit, redirect, query. For special keywords usage please read the doc/Factoids.txt help file."

**Keywords have been refactored since V.1.6 to be almost compatible with** [infobot](http://www.infobot.org/guide-0.43.x.html) - see the Factoids.txt help below.

* Subcommands: new - add - delete - forget - list - show - find

1. new (store a new fact): @kw new BirbaBot is A POE Powered IRC Perl Bot

2. add (add another definition to an existing fact - up to 3): @kw add BirbaBot is a cat, see http://it.wikipedia.org/wiki/Birba

3. delete (remove a definition from a fact who has many): @kw delete BirbaBot 2 (definition 2 will be purged from BirbaBot fact)

4. forget (completely forget about fact and all of its definitions): @kw forget BirbaBot

* Asking the bot for a factoid:

That's simple: just ask a fact prefixed by kw_prefix (as chosen in configuration file)

!BirbaBot

    A POE Powered IRC Perl Bot, or a cat, see http://it.wikipedia.org/wiki/Birba

* Tell a fact to somebody else

1. In channel: BirbaBot > john
2. In query: BirbaBot >> john

#### Config Option

Starting from commit "ff598791764981df47ff845212f9ff2a4e9a7c63" pushed on Mon, 13 May 2013 02:20:29 +0000 (04:20 +0200), we don't use questions anymore to ask for a fact; we use a prefix instead, that is "kw_prefix" (in the bot config section, see example.conf). So, if the kw_prefix is set to "!", "!ping" queries the bot for a fact named "ping". N.B. Do not set the same prefix for keywords and bot commands.

#### Factoids usage notes

Each factoid in BirbaBot can have at maximum 3 different definitions, like bar1, bar2 and bar3. Special keywords just works for the first key definition "bar1".

The keywords are:

1. $nick | $who  (addressing)
2. <reply> see   (recursion)
3. <action>      (ctcp action)

What do they do?

1)

"$who" or "$nick" get evaluated and substituted with the nickname of the person who asked the factoid. The factoid must have ONLY one definition (bar1) for it to work. bar2/3 which contain such variables will be told without interpolation.

EXAMPLE:

    @kw new hello is hello $who!
    asking: !hello
    outputs: hello roughnecks!

2)

The word "see" operates like a recursion and it is transparent to the user. The factoid's value must always begin with the keyword "<reply> see" and the factoid must have ONLY one definition (bar1) for it to work.

EXAMPLE:

    @kw new hi is <reply> see hello
    @kw new hello is Hello, how are you today?
    asking: !hi
    does a query against "hi" -> finds a "<reply> see" tag followed by "hello" -> does a new query against "hello" 
    outputs: Hello, how are you today?

3)

The keyword <action> triggers the bot to spit a factoid while doing a "ctcp action". The factoid's value must always begin with the keyword "<action>" and the factoid must have ONLY one definition (bar1) for it to work.

EXAMPLE

    @kw new smile is <action> lols :)
    asking: !smile
    the bot performs a ctcp action
    outputs: * Birba lols :)


QUOTING

Normally, the word 'is' is considered a separator between the keyword and the definition. In some case, you may want to include this word in the keyword. In this case you must quote the definition with "".

EXAMPLE

    @kw new "what time is it" is I don't know
    asking: !what time is it
    bot replies: I don't know

Without quoting you would get 'what time' => 'it is I don't know'

The complete help about facts can be found in doc/Factoids.txt.

Contacts
--------

For any other help, contacts and informations:

** freenode IRC Network, #BirbaBot
