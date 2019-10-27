#! /bin/bash

rm _site -rf
bundle exec jekyll serve --incremental --watch --port 8080 > server.log 2>&1 & 
