#! /bin/bash

ps -a | grep "jekyll serve --incremental" | grep -v grep | cut -f 2 -d " " | xargs kill -9
rm -rf _site
