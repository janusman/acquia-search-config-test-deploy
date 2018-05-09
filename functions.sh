#!/bin/sh

# See http://linuxtidbits.wordpress.com/2008/08/11/output-color-on-bash-scripts/
COLOR_RED=$(tput setaf 1) #"\[\033[0;31m\]"
COLOR_YELLOW=$(tput setaf 3) #"\[\033[0;33m\]"
COLOR_GREEN=$(tput setaf 2) #"\[\033[0;32m\]"
COLOR_GRAY=$(tput setaf 7) #"\[\033[2;37m\]"
COLOR_NONE=$(tput sgr0) #"\[\033[0m\]"

function header() {
  echo ""
  echo "${COLOR_GRAY}._____________________________________________________________________________"
  echo "|${COLOR_GREEN}  $1${COLOR_NONE}"
}

function pausemsg() {
  echo ""
  echo " ** ${COLOR_GREEN}PRESS ENTER TO CONTINUE.${COLOR_NONE} **"
  read
  echo ""
  echo ""
}

function errmsg() {
  echo $0 >>$tmpout_errors
  echo "${COLOR_RED}$1${COLOR_NONE}" 
}

function warnmsg() {
    echo "${COLOR_YELLOW}$1${COLOR_NONE}"
}
