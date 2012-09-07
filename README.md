BirbaBot, a POE Powered IRC Bot
===============================

![birbabot](https://github.com/roughnecks/BirbaBot/tree/master/files/birba.jpg)

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
    libyaml-perl			   YAML::Any
    libsocket6-perl			   Socket6	## with perl >= 5.14 this module is not needed
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


Contacts
--------

For any other help, contacts and informations:

** freenode IRC Network, #BirbaBot
