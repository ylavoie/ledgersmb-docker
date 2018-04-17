#!/bin/bash

echo "git diff $1 $2 $3"
DISPLAY=ylaho3:0 meld $1 $2
#DISPLAY=ylaho3:0 kdiff3 $1 $2
#colordiff -bBwiZyW 143 $1 $2 | less -r
