#! /bin/bash

rm _site -rf
bundle exec jekyll serve --incremental --port 8080 > server.log & 
