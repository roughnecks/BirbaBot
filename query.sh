#!/bin/bash

rm ./test.db

sqlite3 test.db < test.sql

echo "query rss table to see which urls needs to be fetched for which channel"
sqlite3 test.db "SELECT url,f_channel FROM rss WHERE active=1;"

echo "query rss table to see which urls of which feed_handle needs to be fetched without duplicates"
sqlite3 test.db "SELECT DISTINCT url,f_handle FROM rss WHERE active=1;"

echo "query feed_handle table(s) to get already fetched urls"
sqlite3 test.db "SELECT url FROM feed_laltromondo;"

echo "query a feed_name to get the last fetched item id for feed_handle"
sqlite3 test.db "SELECT f_id FROM feed_laltromondo ORDER BY f_id DESC LIMIT 1;"

echo "query a feed_name to get the last 2 fetched items for feed_handle (from all tables)"
sqlite3 test.db "SELECT * FROM feed_laltromondo ORDER BY f_id DESC LIMIT 2;"

echo "query a feed_name to get the last 2 fetched items for feed_handle (from selected tables)"
sqlite3 test.db "SELECT f_handle,title,url FROM feed_laltromondo ORDER BY f_id DESC LIMIT 2;"

echo "query to select active feeds in channel f_channel (e.g. #laltromondo)"
sqlite3 test.db "SELECT f_handle FROM rss WHERE f_channel='#l_altro_mondo' AND active=1;"

