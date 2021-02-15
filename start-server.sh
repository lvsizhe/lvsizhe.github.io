#! /bin/bash

rm -rf _site
bundle exec jekyll serve --incremental --watch --port 8080 > server.log 2>&1 & 
