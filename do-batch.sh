#!/bin/bash
# Applies a single set of config into a batch of cores
# Instructions:
# * Place the config files into a folder called "ticketfiles" on the current folder
# * Make a txt file with a list of cores, one core per line (just the core ID)
# * Copy the ticket number and use it as the second argument
# Invoke like this:
#   bash do-batch.sh list.txt [ticketnumber]
infile=${1:-x}
ticket=${2:-x}
if [ ! -r $infile ]
then
  echo "File $infile does not exit"
  exit 1
fi

if [ "$ticket" = x ]
then
  echo "You need to provide a ticket number (i.e. 1234567) as the second argument"
  exit 1
fi

if [ ! -f ./check-solr-config.sh ]
then
  echo "Could not find check-solr-config.sh in the current folder"
  exit 1
fi

for nom in `cat $infile`
do 
  echo ""
  echo "================================================================================="
  echo "== $nom"
  echo "== "`date`
  echo "========="
  #governor.phar index:ping $nom |grep false
  #continue
  ./check-solr-config.sh $ticket $nom ticketfiles --no-comment --auto-wait-governor
  if [ $? -gt 0 ]
  then
    echo "$0: ERROR WHEN RUNNING check-solr-config.sh, stopping script! "`date`
    exit 1
  fi
  #echo "Sleeping for 10 seconds..."
  #sleep 10
  echo ""
done
