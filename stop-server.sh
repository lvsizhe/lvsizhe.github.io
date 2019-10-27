#! /bin/bash

ps -a --format pid,cmd | grep "jekyll serve --incremental" | grep -v grep | cut -f 2 -d " " | xargs kill -9
rm _site -rf
