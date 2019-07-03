#!/bin/bash
# parse-solr-config-ticket.sh
# https://gist.github.com/janusman/e6365dc999c41a133cf6

# Constants #########################
# Get the path to this script
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Include ##############
. $BASE_DIR/functions.sh

if [ ${1:-x} = x ]
then
  echo "${COLOR_YELLOW}Usage: $0 ticket-number"
  echo
  echo "Tries to automate custom configuration tickets by downloading all attachments"
  echo " and detect any core IDs mentioned in ticket comments.$COLOR_NONE"
  exit 0
fi

ticket=$1
tmpout=/tmp/$$.output.json
tmpout_errors=/tmp/$$.errors.tmp
CREDS_FILE=creds.txt

if [ ! -r creds.txt ]
then
  errmsg "Place a one-liner into a creds.txt file, with this information:"
  errmsg "  YourEmail@acquia.com:PassWordUsedToLogIntoZendesk"
  errmsg "Or, a ZD API token string:"
  errmsg "  YourEmail@acquia.com/token:TokenString$COLOR_NONE"
  exit 0
fi
credentials=`cat $CREDS_FILE`
curl -su $credentials https://acquia.zendesk.com/api/v2/tickets/${ticket}/comments.json >$tmpout

if [ `grep -c "Couldn't authenticate you" $tmpout` -eq 1 ]
then
  errmsg "Couldn't authenticate against Zendesk. Make sure $CREDS_FILE has the correct credentials."
  exit 1
fi

# Do some maintenance to keep temp folders manageable
header "Housekeeping..."
echo "Deleting really old folders (>100 days)"
find old -maxdepth 1 -type d -mtime +90 -name 'z*' -print -exec rm -rf "{}" \;

echo "Moving older z* folders to old/"
find -maxdepth 1 -type d -ctime +30 -name 'z*' -print -exec mv "{}" old/ \;

# Clean out and create destination folder
DEST_FOLDER=z${1}
rm -rf $DEST_FOLDER
mkdir -p $DEST_FOLDER
cd $DEST_FOLDER
echo "Created destination folder $DEST_FOLDER/"

# Process comments and download attachments
header "Processing ticket"
cat $tmpout |php -r '

function sep() {
  return str_repeat("=", 70) . "\n";
}
$result = json_decode(trim(stream_get_contents(STDIN)));
$attachments = array();
$cores = array();

foreach ($result->comments as $cid => $comment) {
  # Show first comment...
  if ($cid == 0) {
    echo "\nFirst comment in ticket: {$comment->created_at}\n" . sep() . wordwrap($comment->body) . "\n" . sep() . "\n";
  }

  # Gather attachments
  if ($comment->attachments) {
    foreach ($comment->attachments as $attachment) {
      $attachments[$attachment->file_name] = $attachment->content_url;
    }
  }

  # Look for core IDs
  if ($comment->body) {
    $ok = preg_match_all("/[A-Z][A-Z][A-Z][A-Z]-[0-9][0-9][0-9][0-9][0-9][0-9]*(\.[a-z0][a-z1][a-zA-Z0-9]*\.[a-zA-Z0-9]*|_[a-zA-Z0-9]*|)/", $comment->body, $matches, PREG_SET_ORDER);
    if ($ok) {
      foreach ($matches as $match) {
        $core = $match[0];
        if ($core != "ABCD-12345") {
          $cores[$core] = $core;
        }
      }
    }
  }

}

echo "\nLast comment in ticket: {$comment->created_at}\n" . sep() . wordwrap($comment->body) . "\n" . sep() . "\n";

# Output detected cores
#echo "cores=" . implode(",", array_keys($cores)) . "\n";

# Download files!
$final_files = array();
system("mkdir ticketfiles 2>/dev/null");
foreach ($attachments as $filename => $url) {

  if (! preg_match("/.*\.(txt|xml|zip|gz)$/", $filename)) {
    echo "Skipping download of $filename...\n";
    continue;
  }

  # TODO: Remove some attachments based on filename extenstion (like .diff?)

  # Use L because we need to follow the redirect
  $cmd = "curl -sL $url -o \"ticketfiles/$filename\"";
  $ok = system($cmd);
  if ($ok === FALSE) {
    echo "# Error! Could not download file from $url\n";
  }
  $final_files[] = "ticketfiles/$filename";
  echo "Downloaded $filename\n";
}

# Write out scripts for each core.
foreach ($cores as $core) {
  $script = "#!/bin/bash\n'$BASE_DIR'/check-solr-config.sh '$ticket' $core ticketfiles\n";
  file_put_contents("{$core}.sh", $script);
  echo "Wrote script to {$core}.sh\n";
}
' | egrep --color '^|[A-Z][A-Z][A-Z][A-Z]-[0-9][0-9][0-9][0-9][0-9][0-9]*(\.[a-z0][a-z1][a-zA-Z0-9]*\.[a-zA-Z0-9]*|_[a-zA-Z0-9]*|)'

folder=`pwd`
cd ticketfiles

# Unzip and un-gzip any applicable files
find -name "*.zip" -exec sh -c 'echo "FOUND zip file {}; running unzip..."; unzip "{}" && rm "{}"' \;
find -name "*.ZIP" -exec sh -c 'echo "FOUND zip file {}; running unzip..."; unzip "{}" && rm "{}"' \;
find -name "*gz" -exec sh -c 'echo "FOUND gz file {}; running gzip -d..."; gzip -d "{}"' \;

# Remove any __MACOSX folders
find -type d -name __MACOSX -exec rm -rf {} 2>/dev/null \;

# Remove trailing _ in files
for nom in *_
do
  if [ "$nom" != "*_" ]
  then
    new_name=`echo "$nom" | sed -e 's/_$//'`
    echo "Renaming $nom ==> $new_name"
    mv "$nom" $new_name
  fi
done

# Change any .xml.txt files to .xml
for nom in *.xml.txt *.xml_.txt
do
  if [ "$nom" != "*.xml.txt" -a "$nom" != "*.xml_.txt" ]
  then
    name_without_txt=`echo "$nom" | sed -e 's/[_]*.txt$//'`
    echo "Renaming $nom ==> $name_without_txt"
    mv "$nom" $name_without_txt
  fi
done

# Rename any schema.txt files to schema.xml (if there are no schema.xml files already)
if [ `find -name schema.txt -o -name schema_xml.txt |wc -l` -eq 1 -a `find -name schema.xml |wc -l` -eq 0 ]
then
  echo "Found schema.txt/schema_xml.txt... renaming to schema.xml"
  find -name schema.txt -o -name schema_xml.txt -exec mv {} schema.xml \;
fi


cd ..
header "DONE"
echo ""
echo "  ${COLOR_GREEN}Created destination folder $DEST_FOLDER/"
echo "  All applicable attachments were downloaded to $DEST_FOLDER/ticketfiles:"
ls -l ticketfiles | awk 'NR>1 {print "    " $0 }'
echo ""
echo "  You can now run these scripts in this folder to process each mentioned index:"
ls *.sh | awk '{print "    " $0 }'

echo '#!/bin/sh' >run-all
echo '#auto_comment="--auto-comment" # Uncomment to auto-comment' >>run-all
echo '#no_deploy="--nodeploy" # Uncomment to auto-comment' >>run-all
cat *.sh |grep check |awk '{ print $0 " $auto_comment $no_deploy" }' >>run-all
chmod +x run-all
echo ""
echo "  Or, you can process all cores now by typing this:"
echo "      cd z${ticket}; ./run-all"
echo "$COLOR_NONE"

rm $tmpout $tmpout_errors 2>/dev/null
