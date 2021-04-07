#!/bin/bash

# check-solr-config.sh
#   https://gist.github.com/janusman/2225f6a4e8f084906011
#   by Alejandro
#
# Requires:
# * Local Solr instance, with all the necessary solr/lib files
# * governor-cli tool
#
# The script does this:
# * Runs basic checks for file format (text, UTF-8-encoding, LF line endings)
# * Copies the configuration files from the live core and places them into the
#   Solr local instance
# * Places the files under git, to track changes
# * Copies the new specified files over the configuration, and attempts to start Solr
# * Reports on any Solr warnings or errors found, and provides a canned response
# * If successful startup, provides links you can click to upload files onto the
#   Governor, and checks for the real index's coming back up.
# * Also provides canned response for successful implementation, including a
#   .diff between previous and new config
#
# TODO
# * Check syntax errors synonyms?
# * Check elevate.xml, do the items exist? lowercased terms??
# * Check for bastion access first before installing :) Make sure the extra lib files are there when checking Solr install.
# * Run governor.phar and check it it's asking for creds, and if so direct to https://cci.acquia.com/node/4491726 for instructions

# Constants #########################
# Get the path to this script
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Other paths
PATH_TO_GOVERNOR_PHAR=${BASE_DIR}/install/governor.phar
PATH_TO_ZD_POST_COMMENT_SCRIPT=${BASE_DIR}/extra/zendesk/post-zendesk-comment.php
PATH_TO_GUV_COPY_MODULE=${BASE_DIR}/extra/guv_copy/guv_copy.module
DRUSHCMD=drush
mkdir ${BASE_DIR}/tmp 2>/dev/null
tmpout=${BASE_DIR}/tmp/check.$$.tmp
tmpout2=${BASE_DIR}/tmp/check.$$.tmp2
tmpout_governor=${BASE_DIR}/tmp/check.$$.tmp3
tmpout_governor_ping=${BASE_DIR}/tmp/check.$$.tmp4
date=`date +%Y-%m-%d`
tmpout_errors=${BASE_DIR}/tmp/errors.$$.tmp

# Include ##############
. $BASE_DIR/functions.sh

# Functions  #########################
function governor-cli() {
  $PATH_TO_GOVERNOR_PHAR $@
}

function solrfullversion() {
  if [ $1 -eq 3 ]
  then
    echo "3.5.0"
  fi
  if [ $1 -eq 4 ]
  then
    echo "4.5.1"
  fi
}

function solrfolder() {
  if [ $1 -eq 3 ]
  then
    echo "$BASE_DIR/install/apache-solr-3.5.0"
  fi
  if [ $1 -eq 4 ]
  then
    echo "$BASE_DIR/install/solr-4.5.1"
  fi
}

# Return the javasrv-XXX for the given ID
function asgetservers() {
  governor-cli index:info $1 |tr -d '\012' |php -r '$result = json_decode(fgets(STDIN)); echo $result->master . "\n" . implode("\n", $result->slaves) . "\n";'
}

# Copy Acquia Search .txt and .xml files from an acquia solr core to a local folder
function ascopyconf() {
  if [ ${1:-x} = x ]
  then
    echo "Copies the Solr config folder to ./XXX-YYYY-conf"
    echo "Usage: ascopyconf acquia_identifier [hostname]"
    echo "Examples:"
    echo "  ascopyconf XYZ-12345"
    return
  fi
  dest="$1-conf"
  if [ -r "$dest" ]
  then
    echo "Error: folder $dest already exists"
    return 1
  fi

  if [ ${2:-x} = x ]
  then
    server=`asgetservers $1 |head -1`
    if [ ${server:-x} = x ]
    then
      echo "Servers for $1 not found. Please specify it as the second parameter (e.g. 'search36')"
      return 1
    fi
  else
    server=$2
  fi

  echo "Copying config from ${server}:/mnt/www/html/*/docroot/files/solr/cores/$1/conf  ..."
  mkdir $dest
  scp -F $HOME/.ssh/ah_config -r ${server}:/mnt/www/html/*/docroot/files/solr/cores/$1/conf/\{*.xml,*.properties,*.txt\} $dest
  echo ""
  echo "DONE! Copied files to ./$dest"
}

# Wait until a core comes down and then back up.
function aswaitforcycle() {
  core=$1
  cat $tmpout_governor_ping |php -r '
  function wait_down_up($url) {
    echo "Waiting for instance at $url to Cycle (come down and back up)\n";
    # Check up
    $up = solr_json_ping($url);
    if (!$up) {
      echo "ERROR: Instance at $url wasnt up at beginning of check!\n";
      exit(1);
    }
    echo "  Instance currently UP. Waiting for it to come DOWN: ";

    # Pause 0.1 seconds and check again until DOWN
    $x = 0;
    $wait = 0.1; # Seconds
    while ($up) {
      $up = solr_json_ping($url);
      usleep($wait*1000000);
      $x++; if ($x%10 == 0) { print "."; }
    }
    $total_time = intval($x*$wait);

    echo "\n  Instance currently DOWN. Waiting for it to come UP: ";

    # Pause and check again until DOWN
    $wait = 0.2; # Seconds
    $timeout = 90; # Seconds
    while (!$up) {
      $up = solr_json_ping($url);
      usleep($wait*1000000);
      echo ".";
      $x++; if ($x%50 == 0) { print "."; }
      if ($x * $wait > $timeout) {
        echo "ERROR: Core at $url did not come up after " . intval($x*$wait) . " seconds.\n";
        exit(1);
      }
    }
    $total_time += intval($x*$wait);
    echo "\n  Instance UP ($total_time sec total). Finished this check.\n\n";

  }
  function solr_json_ping($url) {
    $result = @json_decode(file_get_contents("$url?wt=json"));
    if (!$result) {
      return false;
    }
    $up = ($result->status == "OK");
    return $up;
  }

  $r = json_decode(trim(stream_get_contents(STDIN)));
  foreach ($r->servers as $server) {
    $url = $server->server;
    wait_down_up($url);
  };
'
}

function file_to_clipboard() {
  # Linux
  which xclip >/dev/null 2>&1
  if [ $? -eq 0 ]
  then
    cat $1 |xclip -i -selection c
    notify-send -i terminal "Check-solr-script.sh" "Copied response to clipboard."
  fi
  # Mac
  which pbcopy >/dev/null 2>&1
  if [ $? -eq 0 ]
  then
    cat $1 |pbcopy
    osascript -e 'display notification "Copied response to clipboard." with title "Check-solr-script.sh"'
  fi
}

function check_governor_access() {
  if [ `$DRUSHCMD sa |grep -c @guvannuh.prod` -eq 0 ]
  then
    echo 0
  else
    echo 1
  fi
}

function asgetgovurl() {
  # Fall back if we don't have Governor drush access.
  if [ `check_governor_access` -eq 0 ]
  then
    echo "https://governor.acquia-search.com/admin/content2?title=$core";
    return
  fi

  # Figure out the URL to a particular core on the Governor.
  $DRUSHCMD @guvannuh.prod ev 'function _guv_copy_get_nids_from_core_id($core_id) {
  $query = new EntityFieldQuery();
  $nodes = $query->entityCondition("entity_type", "node")
    ->entityCondition("bundle", "si_search_core")
    ->fieldCondition("field_id", "value" , $core_id, "=      ")
    ->execute();
  if (isset($nodes["node"])) {
    return array_keys($nodes["node"]);
  }
  return array();
}
$core = "'$1'";
$result = _guv_copy_get_nids_from_core_id($core);
if (sizeof($result) == 1) {
  echo "https://governor.acquia-search.com/node/" . $result[0] . "/edit\n";
}
else {
  echo "https://governor.acquia-search.com/admin/content2?title=$core\n";
}'
}

function deploy_files_into_governor() {
  CORE=$1 # E.g. ABCD-12345
  FILES_FOLDER=$2  #E.g. /path/to/the-files-folder (which would contain synonyms.txt, schema.xml, etc.)
  COMMENT_TEXT_FILE=$3  # E.g. /path/to/something.txt (which )

  CODE_file=$PATH_TO_GUV_COPY_MODULE
  REMOTE_site_env=guvannuh.prod
  XFER_foldername="xferfolder-$$"
  # Make a local tmp folder
  LOCAL_xfer_root=`mktemp -d`
  LOCAL_xfer_folder=${LOCAL_xfer_root}/${XFER_foldername}
  mkdir $LOCAL_xfer_folder 2>/dev/null

  ########
  # Build folder with items to transfer:
  # * files folder
  # * Revision log comment
  # * Additional code

  # Write change summary
  cp $COMMENT_TEXT_FILE $LOCAL_xfer_folder/change-summary-with-ticket.txt
  # Copy the code
  cp $CODE_file $LOCAL_xfer_folder
  # Copy the files
  cp -R $FILES_FOLDER $LOCAL_xfer_folder

  ########
  # Transfer the folder
  # https://drupal.stackexchange.com/questions/145239/how-to-scp-one-file-to-remote-using-drush
  echo "Transfering files..."
  REMOTE_xfer_root=/mnt/tmp/${REMOTE_site_env}
  REMOTE_xfer_folder=${REMOTE_xfer_root}/${XFER_foldername}
  tmp=`pwd`
  cd ${LOCAL_xfer_root}
  tar zcf - $XFER_foldername | $DRUSHCMD @${REMOTE_site_env} ssh "tar xvz -C $REMOTE_xfer_root"
  cd $tmp

  ########
  # Deploy into the node
  echo "Calling remote code..."
  #echo '# Drush command: drush @'${REMOTE_site_env}' --uri=https://governor.acquia-search.com ev
  $DRUSHCMD @${REMOTE_site_env} --uri=https://governor.acquia-search.com ev '
    $dir = "'${REMOTE_xfer_folder}'";
    include "$dir/guv_copy.module";
    _guv_copy_do_copy_folder_to_coreids(
      "$dir/'`basename ${FILES_FOLDER}`'",
      array("'$CORE'"),
      file_get_contents("$dir/change-summary-with-ticket.txt")
    );
    ';

  # Remove local folder
  rm -rf $LOCAL_xfer_root
}


function ticket_reply_interactive() {
  zendesk_ticket=$1
  ticket_response_file=$2
  attachment_file=$3
  public_private_flag=$4
  
  if [ ${NO_COMMENT:-0} -eq 1 ]
  then
    warnmsg "NO-COMMENT flag on, skipping"
    cat <<EOF
      
  This would be the ticket comment on ${zendesk_ticket_url}

- - - - - - - - - - - - - - - - - - - - -${COLOR_GRAY}
EOF

  cat $ticket_response_file
  cat <<EOF

${COLOR_NONE}- - - - - - - - - - - - - - - - - - - - -

With this file attached to the ticket:
  ${COLOR_GRAY}$attachment_file${COLOR_NONE}

EOF
    return 0
  fi

  # Offer option to reply into zendesk directly, if we have proper config.
  if [ -r $BASE_DIR/creds.txt ]
  then
    if [ ${AUTO_COMMENT:-0} -eq 1 ]
    then
      echo "${COLOR_YELLOW}Auto-comment flag enabled${COLOR_NONE}"
      next_step=auto_comment
    else
      # Prompt for next step
      PS3='Please select how you want to reply to customer: '
      options=("Have this script automatically post a reply into Zendesk for you" "You will manually post a reply")
      select opt in "${options[@]}"
      do
        case $opt in
          "Have this script automatically post a reply into Zendesk for you")
            next_step=auto_comment
            break;
            ;;
          "You will manually post a reply")
            next_step=manual_comment
            break;
            ;;
          *) echo invalid option;;
        esac
      done
    fi
  else
    warnmsg "Note: If you had a creds.txt file at $BASE_DIR then this script could post a reply directly into Zendesk."
    next_step=manual_comment
  fi

  ## Attempt to do ticket reply automatically
  if [ $next_step = 'auto_comment' ]
  then
    cmd="php -f $PATH_TO_ZD_POST_COMMENT_SCRIPT $zendesk_ticket $ticket_response_file $attachment_file $public_private_flag"
    echo "Running command: $cmd"
    $cmd
    # Handle errors
    if [ $? -gt 0 ]
    then
      errmsg "ERROR: Could not post comment/file automatically into ticket."
      errmsg "       PLEASE POST COMMENT MANUALLY below!"
    else
      echo "${COLOR_GREEN}Posted comment successfully!${COLOR_NONE}"
      echo ""
      return 0
    fi
  fi

  ## Ticket reply will be done manually.
  # Copy ticket response to Clipboard
  file_to_clipboard $ticket_response_file
  cat <<EOF

Please use this as a ticket reply
  on ${zendesk_ticket_url}

- - - - - - - - - - - - - - - - - - - - -${COLOR_GRAY}
EOF

  cat $ticket_response_file
  cat <<EOF

${COLOR_NONE}- - - - - - - - - - - - - - - - - - - - -

ATTACH this file to the ticket:
  ${COLOR_GRAY}$attachment_file${COLOR_NONE}

EOF

  pausemsg
}

function get_governor_queue_length() {
  curl -s https://governor.acquia-search.com/ACQUIA_SEARCH_GOVERNOR_MONITOR |php -r '$result = json_decode(trim(stream_get_contents(STDIN))); print_r($result->queue_items);'
}

############################################
# Start!

# Run requirements checks
ok=1
# Commands needed
for command in php java file curl $DRUSHCMD mktemp composer git
do
  which $command >/dev/null
  if [ $? -gt 0 ]
  then
    errmsg "Requirement: Can't find the required command $command in current path, please install it or add it to the current path."
    ok=0
  fi
done

# Check Java version
if [ `java -version 2>&1 |grep -c 'build [0-9]'` -eq 0 ]
then
  errmsg "Requirement: Java is not installed! Please install it. Instructions: https://www.java.com/en/download/help/download_options.html"
  exit 1
fi

# Check drush version
if [ `$DRUSHCMD --version 2>&1 |egrep -c '9\.|1[012]\.'` -eq 1 ]
then
  warnmsg "WARNING: Your local drush version is drush 9 or higher, which may not work when talking to the Governor."
  warnmsg "You can edit the script's DRUSHCMD line and add the path to your local drush7 or drush8 command."
  echo "You can also ignore this warning if you plan to upload configuration manually to the Governor."
  echo ""
  pausemsg
fi

# Do some maintenance to keep temp folders manageable
header "Housekeeping..."
echo "Deleting old tmp/ folders (>10 days)"
find $BASE_DIR/tmp -maxdepth 1 -type d -mtime +10 -name 'check-config-tmp-*' -print -exec rm -rf "{}" \;
find $BASE_DIR/tmp -maxdepth 1 -type f -mtime +10 -name 'check.*' -print -exec rm -rf "{}" \;

function install_governor_cli() {
  echo "  ${COLOR_YELLOW}Installing governor.phar tool...${COLOR_NONE}"
  cur_folder=`pwd`
  mkdir $BASE_DIR/install 2>/dev/null
  cd $BASE_DIR/install
  
  if [ ! -r acquia-search-governor-php/vendor/acquia/acquia-sdk-php-rest ]
  then
    git clone git@github.com:acquia/acquia-search-governor-php.git
    cd acquia-search-governor-php
    composer install
    # Patch as per https://patch-diff.githubusercontent.com/raw/acquia/acquia-sdk-php/pull/79
    cd ./vendor/acquia/acquia-sdk-php-rest
    echo -n "Downloading and applying patch..."
    curl -s https://patch-diff.githubusercontent.com/raw/acquia/acquia-sdk-php/pull/79.diff -o 79.diff
    patch -p2 <79.diff
    echo " done!"
  fi
  # Add the command
  cat <<EOF >$PATH_TO_GOVERNOR_PHAR
#!/bin/bash
php $BASE_DIR/install/acquia-search-governor-php/bin/governor.php \$@
EOF
  chmod +x $PATH_TO_GOVERNOR_PHAR
  cd $cur_folder
}

# Governor cli tool
#where=`which governor.phar`
#if [ $? -eq 0 ]
#then
#  cp $where $PATH_TO_GOVERNOR_PHAR 2>/dev/null
#fi

if [ ! -r $PATH_TO_GOVERNOR_PHAR ]
then
  errmsg "Requirement: Can't find $PATH_TO_GOVERNOR_PHAR!"
  # Install it!
  install_governor_cli
fi

if [ `governor-cli --no-ansi |grep -c Options` -lt 1 ]
then
  errmsg "Can't seem to execute php $PATH_TO_GOVERNOR_PHAR, check settings!"
  ok=0
else
  # Check that the credentials are in place
  if [ ! -r $HOME/.Acquia/auth/governor.json ]
  then
    errmsg "Requirement: Can't find stored public/private key for governor.phar"
    errmsg "  1) RUN this command from the commandline:"
    errmsg "     $PATH_TO_GOVERNOR_PHAR colony:list"
    errmsg "  2) When prompted for private/public key, enter credentials from https://cci.acquia.com/node/4491726"
    ok=0
  fi
fi

# Ensure we have local solr instances
cur_folder=`pwd`
cd $BASE_DIR
for solr_version in 3 4
do
  solr_dir=`solrfolder $solr_version`
  if [ ! -r $solr_dir ]
  then
    # NO Solr found, DOWNLOAD IT!
    errmsg "Requirement: Can't find local Solr installation at $solr_dir"

    # Calculate the download URL
    url=http://archive.apache.org/dist/lucene/solr/3.5.0/apache-solr-3.5.0.tgz
    if [ $solr_version = 4 ]
    then
      url=http://archive.apache.org/dist/lucene/solr/4.5.1/solr-4.5.1.tgz
    fi
    echo "  ${COLOR_YELLOW}Installing Solr v$solr_version from $url...${COLOR_NONE}"

    # Download, uncompress and get rid of tmp file.
    curl $url -o /tmp/download.tgz
    mkdir $solr_dir
    cd $solr_dir
    cd ..
    tar -zxf /tmp/download.tgz
    rm /tmp/download.tgz
    echo ""

    ## Add extra libraries from Acquia Search
    echo "  Copying extra Solr libraries from an Acquia Search farm..."
    if [ $solr_version = 3 ]
    then
      # Solr 3
      rsync -e "ssh -F $HOME/.ssh/ah_config" -rltDz --rsync-path="/usr/bin/sudo /usr/bin/rsync" javasrv-71.search-service.hosting.acquia.com:/vol/backup-ebs/gfs/useast1ass2m/tomcat6/webapps/solr/WEB-INF/lib ${solr_dir}/example/solr
    else
      # Solr 4
      rsync -e "ssh -F $HOME/.ssh/ah_config" -rltDz --rsync-path="/usr/bin/sudo /usr/bin/rsync" javasrv-253.search-service.hosting.acquia.com:/vol/backup-ebs/gfs/useast1ass73m/tomcat6/webapps/solr/WEB-INF/lib ${solr_dir}/example/solr
      # Move this folder out of the way because it's not in our servers.
      #mv ${solr_dir}/example/solr/collection1/conf/lang ${solr_dir}/example/solr/collection1/conf/lang_ORIG
      #mkdir ${solr_dir}/example/solr/collection1/conf/lang
      #echo "## EMPTY file put here by $0" >${solr_dir}/example/solr/collection1/conf/lang/stopwords_en.txt
    fi
    echo "  Done installing $solr_dir"
  else
    if [ ! -r $solr_dir/example/start.jar ]
    then
      errmsg "Requirement: Can't find $solr_dir/example/start.jar; make sure settings point to correct folder"
      ok=0
    fi
  fi
done
cd $cur_folder



# Get options
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL=()
NO_DEPLOY=0
AUTO_COMMENT=0
AUTO_WAIT_GOVERNOR=0
NO_COMMENT=0
NO_PING=0
IGNORE_BAD_UTF=0
IGNORE_SOLRCONFIG_WARNING=0
SKIP_CHECK_XML=0
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in


  # Normal option processing
    -h | --help)
      HELP=1
      ;;
  # Special cases
    --)
      break
      ;;
  # Long options
    --help)
      HELP=1
      ;;
    #--stages=*)
    #  STAGE=$1
    #  ;;
    --no-deploy|--nodeploy)
      NO_DEPLOY=1;
      ;;
    --auto-comment|--autocomment)
      AUTO_COMMENT=1;
      ;;
    --no-comment|--nocomment)
      NO_COMMENT=1;
      ;;
    --auto-wait-governor)
      AUTO_WAIT_GOVERNOR=1;
      ;;
    --no-ping|--noping)
      NO_PING=1;
      ;;
    --disable-utf-error)
      IGNORE_BAD_UTF=1;
      ;;
    --disable-xml-check)
      SKIP_CHECK_XML=1;
      ;;
    --ignore-solrconfig-warning)
      IGNORE_SOLRCONFIG_WARNING=1;
      ;;
    --*)
      # error unknown (long) option $1
      echo "  ${COLOR_RED}Warning: Unknown option $1${COLOR_NONE}"
      ;;
    -?)
      # error unknown (short) option $1
      ;;

  # MORE FUN STUFF HERE:
  # Split apart combined short options
  #  -*)
  #    split=$1
  #    shift
  #    set -- $(echo "$split" | cut -c 2- | sed 's/./-& /g') "$@"
  #    continue
  #    ;;

  # Done with options, parse other options
  *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    ;;
  esac

  shift
done

set -- "${POSITIONAL[@]}" # restore positional parameters

# Arguments  #########################
zendesk_ticket="${1:-x}"
core="${2:-x}"
files="${3:-x}"
zendesk_ticket_url="https://acquia.zendesk.com/agent/tickets/${zendesk_ticket}"

cat <<EOF
  Ticket: $zendesk_ticket ($zendesk_ticket_url)
    Core: $core
   Files: $files
 Options: ---------------------------------
           no-deploy: $NO_DEPLOY
        auto-comment: $AUTO_COMMENT
          no-comment: $NO_COMMENT
             no-ping: $NO_PING
  auto-wait-governor: $AUTO_WAIT_GOVERNOR
   disable-utf-error: $IGNORE_BAD_UTF
  ignore-solrconfig-warning: $IGNORE_SOLRCONFIG_WARNING
EOF

# Output help if no index or files
if [ ${HELP:-x} = 1 -o ${core} = x -o "${files:-x}" = x -o ${zendesk_ticket:-x} = x ]
then
  header $0
  cat <<EOF
  Script that takes automates testing of customer-submitted Acquia Search configuration files
  with file format checking (UTF-8, LF line endings), testing on local Solr instance, and
  builds a canned response for customer, along with links and text for the "revision log entry"
  to edit the index node on http://governor.acquia-search.com/

${COLOR_YELLOW}Usage:${COLOR_NONE}
  $0 zd-ticket-number index-id file [options]
  $0 zd-ticket-number index-id folder [options]
  $0 zd-ticket-number index-id "file1 file2 file3" [options]

Options:
         [--no-deploy] : Skips the deployment steps.
           [--no-ping] : Skips checking if the Solr core cycles (comes down and back up).
        [--no-comment] : Skip posting any comments.
      [--auto-comment] : Auto-posts public comment to Ticket if everything looks OK.
[--auto-wait-governor] : Automatically wait for governor queue to come down before continuing.
 [--disable-utf-error] : Skip UTF-8 checks in config files.
 [--disable-xml-check] : Skip XML check.
[--ignore-solrconfig-warning] : Skip warning and stopping for solrconfig.xml changes.


${COLOR_YELLOW}Examples:${COLOR_NONE}
  ${COLOR_GRAY}# Check synonyms.txt from current folder, ticket Z123456, for core WXYZ-12345.dev.default${COLOR_NONE}
  ./check-solr-config.sh 123456 WXYZ-12345.dev.default synonyms.txt

  ${COLOR_GRAY}# Check files from 'filesfolder' folder, ticket Z123456, for core WXYZ-12345.dev.default${COLOR_NONE}
  ./check-solr-config.sh 123456 WXYZ-12345.dev.default filesfolder

  ${COLOR_GRAY}# Same as above, but multiple files.
  #   Mind the quotes!${COLOR_NONE}
  ./check-solr-config.sh 123456 WXYZ-12345.dev.default "stopword_pl.txt synonyms_pl.txt schema_extra_types.xml"
EOF
  exit $ok
fi

# Check Governor is actually not too backed up!
governor_queue_items=`get_governor_queue_length`
if [ $governor_queue_items -gt 10 ]
then
  errmsg "WARNING: Acquia's Search Governor is currently churning thru $governor_queue_items tasks..."
  
  if [ ${AUTO_WAIT_GOVERNOR:-0} -eq 1 ]
  then
    warnmsg "  Option --auto-wait-governor is enabled"
    next_step=wait
  else
    # Prompt for next step
    PS3='Please select how you want to continue: '
    options=("Wait until the queue clears" "Continue without waiting")
    select opt in "${options[@]}"
    do
      case $opt in
        "Wait until the queue clears")
          next_step=wait
          break;
          ;;
        "Continue without waiting")
          errmsg "NOTE: Response times might be slow for this process"
          next_step=continue
          break;
          ;;
        *) echo invalid option;;
      esac
    done
  fi

  if [ $next_step = "wait" ]
  then
    echo -n "Waiting until Governor cools down..."
    while [ 1 ]
    do
      governor_queue_items=`get_governor_queue_length`
      if [ $governor_queue_items -gt 4 ]
      then
        echo -n "."
        sleep 10
      else
        echo "queue now at $governor_queue_items, continuing!"
        break;
      fi
    done
  fi
fi

if [ $ok -eq 0 ]
then
  echo "Requirements not met. Exiting!"
  exit 1
fi

# Create tmp folder
tmpdir="$BASE_DIR/tmp/check-config-tmp-${core}"
if [ -r $tmpdir ]
then
  warnmsg "Warning: Previous folder $tmpdir found, moving to ${tmpdir}-BAK"
  rm -rf ${tmpdir}-BAK 2>/dev/null
  mv $tmpdir ${tmpdir}-BAK
fi
mkdir -p $tmpdir
newfiles_dir="$tmpdir/newfiles"
mkdir -p $newfiles_dir
realfilestoupload_dir="$tmpdir/upload_files"
mkdir -p $realfilestoupload_dir
ticket_response_file="${tmpdir}/ticket-response-$core.txt"


# If 'files' is actually a folder, use that
if [ -d $files ]
then
  echo "Using files from folder $files..."
  ls $files
  files=`find $files -type f |fgrep -v .git`
fi

# Check that incoming files are UTF-8
header "Checking incoming file format"

echo "" >$tmpout_errors
error=0
for file in $files
do
  copy=1
  if [ ! -r "$file" ]
  then
    errmsg "Error: File $file not found"
    error=1
  else
    # Check empty files
    if [ `file $file | grep -c 'empty'` -eq 1 ]
    then
      warnmsg "WARNING: $file is an empty file"
    fi

    # Flag what could be wrong extensions
    if [ `php -r 'echo substr_count(basename("'$file'"), ".");'` -gt 1 ]
    then
      warnmsg "WARNING: $file may have wrong extension!"
    fi

    # Check file encoding is UTF (or something that passes for UTF)
    cat $file |php -r '$str = stream_get_contents(STDIN); $is_utf = mb_detect_encoding($str, "UTF-8", TRUE); exit ($is_utf ? 0 : 1);'
    if [ $? -eq 1 ]
    then
      if [ $IGNORE_BAD_UTF -eq 0 ]
      then
        errmsg "ERROR: File $file is not UTF-8-encoded, should be UTF-8 (without BOM). Use the --disable-utf-error flag to downgrade this error to a warning."
        error=1
      else
        warnmsg "ERROR: File $file is not UTF-8-encoded, should be UTF-8 (without BOM)"
      fi
    fi
    # Check for BOM in file
    cat $file | php -r '$str = stream_get_contents(STDIN); $has_bom = false; $bom = pack("CCC", 0xef, 0xbb, 0xbf); if (0 === strncmp($str, $bom, 3)) { $has_bom = true; } exit ($has_bom ? 1 : 0);'
    if [ $? -eq 1 ]
    then
      warnmsg "Warning: File $file has UTF-8 BOM"
    fi
    if [ `file $file | grep -c 'CRLF'` -eq 1 ]
    then
      warnmsg "Warning: File $file has CRLF endings (line endings should be LF)"
      #error=1
    fi
    # For xml files, check the syntax.
    extension=`echo $file |awk -F. '{ print $NF }'`
    if [ ${extension:-x} = xml -a ${SKIP_CHECK_XML} = 0 ]
    then
      php -r '$is_xml=@simplexml_load_file("'$file'"); exit ($is_xml ? 0 : 1);'
      if [ $? -eq 1 ]
      then
        errmsg "ERROR: File $file is not valid XML."
        # Run xmllint if available
        which xmllint >/dev/null 2>&1
        if [ $? -eq 0 ]
        then
          echo "XML checker flagged these errors:" >>$tmpout_errors
          xmllint $file >>$tmpout_errors 2>&1
          echo "---------------------------------" >>$tmpout_errors
        fi
        error=1
      fi
    fi
    #if [ ${extension:-x} = html -o ${extension:-x} = properties -o ${extension:-x} = xsl -o ${extension:-x} = conf ]
    if [ ${extension:-x} != txt -a ${extension:-x} != xml ]
    then
      warnmsg "Warning: File $file WILL BE OMMITTED because of extension (we only accept .txt and .xml files)"
      copy=0
    fi
    # Check synonyms*.txt format (only non-zero-sized files)
    if [ `echo $file | egrep -c 'synonyms.*txt'` -eq 1 ]
    then
      # Do not check syntax for 0-lined files (could be just \r\n)
      if [ `wc -l $file |cut -f1 -d' '` -gt 1 ]
      then
        # If file has at least one line that isn't a comment, it must have at least one line with a , or => syntax
        if [ `egrep -c "^[^#]" $file` -gt 0 -a `egrep -c "^[^#]*,|=>" $file` -eq 0 ]
        then
          errmsg "ERROR: Synonyms file $file doesn't have the correct syntax: If file has at least one line that is not a comment, it must use the correct syntax"
          error=1
        fi
      fi
    fi
    if [ ${copy} -eq 1 ]
    then
      cp $file $newfiles_dir
    fi
  fi
done

if [ $error -eq 1 ]
then
  errmsg "Fatal errors found, exiting!"
  cat <<EOF >$ticket_response_file
Hello,

We could not deploy your configuration into ${core}, because of the following error(s) thrown by our checking scripts:

\`\`\`
EOF
cat $tmpout_errors >>$ticket_response_file
cat <<EOF >>$ticket_response_file
\`\`\`

After you correct any errors, please re-attach all changed files to the ticket.

Note that you can obtain the current Solr configuration files at any time via Drupal, using either of these methods:

* If using apachesolr.module: go to \`/admin/reports/apachesolr/\` and click on a server. Then, use the "Configuration Files" tab to access the Solr configuration files.
* If using search_api_solr.module: go to \`/admin/config/search/search_api\` and click on a server name. Then, use the "Files" tab to access the Solr configuration files.

We recommend you check it does work and causes the behavior you intended in a local Solr instance. If you require documentation on setting up a local Solr instance for testing, please see: https://support.acquia.com/hc/en-us/articles/360004423034-How-to-test-a-custom-Solr-schema-file-locally
EOF

  # Trigger interactive ticket reply
  ticket_reply_interactive $zendesk_ticket $ticket_response_file $tmpout_errors public

  exit 1
else
  echo "All files OK!"
fi

if [ -f $newfiles_dir/solrconfig.xml ]
then
  warnmsg "Warning: provided solrconfig.xml as a file"
  warnmsg "  Acquia usually does NOT provision solrconfig.xml"
  warnmsg "  Further down we will check if the file DOES change anything, and if so pause for your input."
fi

# Get index information
header "Index information for $core"
# Prefetch the URLs needed for pinging for faster up/down check later
governor-cli index:ping $core >$tmpout_governor_ping 2>&1
governor-cli index:info $core >$tmpout_governor 2>&1

# If no core, report and exit
if [ `grep -ci "Not Found" $tmpout_governor` -gt 0 ]
then
  errmsg "Core $core not found in Governor. It could be unpublished or does not exist"
  exit 1
fi
if [ `grep -ci "Not Found" $tmpout_governor_ping` -gt 0 ]
then
  errmsg "Core $core found in Governor but is currently down (or not fully provisioned)."
  echo "Governor info:"
  cat $tmpout_governor 
  echo "Ping info:"
  cat $tmpout_governor_ping
  echo ""
  exit 1
fi

# Get Solr version
cat $tmpout_governor |php -r '$result = json_decode(trim(stream_get_contents(STDIN))); echo "solr_version=" . (preg_match("/solr.*4/i", $result->colony) ? 4 : 3) . "\n";' >$tmpout2
. $tmpout2
echo "Solr version: $solr_version"
solr_full_version=`solrfullversion $solr_version`
if [ $? -gt 0 ]
then
  errmsg "Error!"
  cat $tmpout_governor
  exit 1
fi

# Show index info
cat $tmpout_governor

# Fetch current config and place under source control
header "Getting current configuration from $core"
cd "$tmpdir"
origconf_dir="${tmpdir}/${core}-conf"
summary_file="${tmpdir}/change-summary.txt"
summary_file_with_ticket="${tmpdir}/change-summary-with-ticket.txt"
if [ -r $origconf_dir ]
then
  warnmsg "Warning: Previous folder $origconf_dir found, moving to ${origconf_dir}-BAK"
  rm -rf ${origconf_dir}-BAK 2>/dev/null
  mv $origconf_dir ${origconf_dir}-BAK
fi

printf "Fetching current configuration into $origconf_dir ..."
ascopyconf $core >/dev/null
echo "done."
cd $origconf_dir
git init . >/dev/null
git add . >/dev/null
git commit -m "Initial commit" >/dev/null

# Get list of new files that already exist
ls $newfiles_dir |sort >$tmpdir/provided-files-list.txt
ls $origconf_dir |sort >$tmpdir/existing-files-list.txt
comm -23 $tmpdir/provided-files-list.txt $tmpdir/existing-files-list.txt >$tmpdir/provided-new-files-list.txt

# Copy files into source control and diff
header "Adding new files from $newfiles_dir and comparing."
changes=0
cp $newfiles_dir/* $origconf_dir
# Add any new files under version control
git add . >/dev/null
git commit -m "Comitting changes" >/dev/null
if [ $? -eq 0 ]
then
  changes=1
  # Generate summary of changes
  echo "  Summary of changes:" >$summary_file
  cd $origconf_dir
  git diff HEAD^ HEAD --ignore-all-space --ignore-blank-lines --stat --color=never | awk '{ print "    " $0 }' >> $summary_file
  if [ `grep -c . $summary_file` -eq 1 -o `grep -c ", 0 insertions..., 0 deletions" $summary_file` -eq 1 ]
  then
    changes=0
  fi
fi

## Ensure we check for new files as well as any changes
if [ $changes -eq 0 -a `grep -c . $tmpdir/provided-new-files-list.txt` -eq 0 ]
then
  errmsg "No changes detected between current and new configuration!"
  echo
  echo "No changes needed, so exiting!"
  exit 0
fi

# There WERE changes, so place files that actually changed to another folder-
# 1) Files that changed:
echo "  .. files that changed:"
git diff  --ignore-all-space --ignore-blank-lines --numstat HEAD^1 |awk '($1 + $2 >0) { print "    " $3}'
cp `git diff  --ignore-all-space --ignore-blank-lines --numstat HEAD^1 |awk '($1 + $2 >0) { print $3}'` $realfilestoupload_dir
# 2) Files that are completely new:
for nom in `cat $tmpdir/provided-new-files-list.txt`
do
  cp $newfiles_dir/$nom $realfilestoupload_dir
  echo "  .. copied completely new file '$nom'"
done
echo "  Copied ONLY the ${COLOR_YELLOW}new and changed${COLOR_NONE} files to $realfilestoupload_dir"
ls -l $realfilestoupload_dir |awk '{ print "    " $0 }'
# Generate the list of REAL files that are overwritten and will need to be removed from the Governor before adding them.
ls $realfilestoupload_dir | sort > $tmpdir/upload-files-list.txt
comm -12 $tmpdir/upload-files-list.txt $tmpdir/existing-files-list.txt >$tmpdir/overwritten-files-list.txt

cat $summary_file

# Generate patch
diff_file="$tmpdir/${core}-${date}-changes.diff"
echo "  Writing patch file to $diff_file"
echo "" >$diff_file
#echo "Acquia Support ticket #${zendesk_ticket}" >> $diff_file
#echo "  Diff file for ${core}, date ${date}" >>$diff_file
#echo "====================================================" >>$diff_file
#echo "Git summary of changes to configuration files:" >>$diff_file
#echo "  Key: (+) lines added, (-) lines deleted" >>$diff_file
#echo "  Note: Files in configuration that had no changes don't show in the list." >>$diff_file
git diff HEAD^ HEAD --ignore-all-space --ignore-blank-lines --patch-with-stat --color=never >>$diff_file


## Special case: solrconfig.xml has changes
if [ `grep -c "solrconfig.xml  *|" $diff_file` -gt 0 -a ${IGNORE_SOLRCONFIG_WARNING:-0} -eq 0 ]
then
  ## Interactively determine if we are going to put it in or not
  if [ `grep "solrconfig.xml  *|" $diff_file |awk '{ print $3 }'` -gt 0 ]
  then
    echo ""
    warnmsg "************************************************************************"
    warnmsg "* Warning: solrconfig.xml was provided, and includes changes!          *"
    warnmsg "************************************************************************"
    warnmsg "  Acquia usually does NOT provision solrconfig.xml"
    warnmsg "  Changes follow:"
    git diff HEAD^ HEAD --ignore-all-space --ignore-blank-lines --color solrconfig.xml >$tmpout
    cat $tmpout
    echo ""

    # Prompt for next step
    PS3='Please select from the options below. (NOTE: You can also hit CTRL-C, delete the solrconfig.xml file and re-run this script): '
    #options=("Accept the changes AND continue" "Omit this file AND add a note to the attached diff file AND continue" "Reject file AND stop script AND show a canned response")
    options=("Accept the changes AND continue" "Reject file AND stop script AND show a canned response")
    select opt in "${options[@]}"
    do
      case $opt in
        "Accept the changes AND continue")
          next_step=continue
          break;
          ;;
        #"Omit this file AND add a note to the attached diff file AND continue")
        #  # Restore file
        #  patch -p1 <$tmpout
        #  #rm solrconfig.xml
        #  # Re-calculate diff
        #  echo "" >$diff_file
        #  echo "NOTE: solrconfig.xml was submitted but REMOVED during this process." >$diff_file
        #  git diff HEAD^ HEAD --ignore-all-space --ignore-blank-lines --patch-with-stat --color=never >>$diff_file

        #  next_step=continue
        #  break;
        #  ;;
        "Reject file AND stop script AND show a canned response")
            cat <<EOF >$ticket_response_file
Hello,

Unfortunately, you have included changes to \`solrconfig.xml\` which would negatively impact the underlying architecture of your Solr instance ${core} (running Solr ${solr_full_version}).

We ask you to:

* Only submit the relevant changes to your solrconfig.xml file OR completely avoid touching this file and use \`solrconfig_extra.xml\` instead.
* Re-test your submissions on a local Solr instance (version ${solr_full_version}), making sure you:
  * 1) get the current configuration files from your Acquia-hosted index $core and install them onto your local Solr testing instance (read below on how to get these files)
  * 2) apply only the needed changes
* After you correct any errors, please re-attach every file changed between step 1 and 2 onto this ticket, confirming the Solr Index ID(s) or URL(s) where we should deploy the changes to.

Note that you can obtain the current Solr configuration files at any time via Drupal, using either of these methods:

* If using apachesolr.module: go to \`/admin/reports/apachesolr/\` and click on a server. Then, use the "Configuration Files" tab to access the Solr configuration files.
* If using search_api_solr.module: go to \`/admin/config/search/search_api\` and click on a server name. Then, use the "Files" tab to access the Solr configuration files.

If you require documentation on setting up a local Solr instance (version ${solr_full_version}) for testing, please see: https://support.acquia.com/hc/en-us/articles/360004423034-How-to-test-a-custom-Solr-schema-file-locally

EOF

          # Interactive/automatic ticket reply
          ticket_reply_interactive $zendesk_ticket $ticket_response_file $tmpout public

          exit 0;
          break;
          ;;
        *) echo invalid option;;
      esac
    done

  fi
fi

#####################################
# Try to check dependencies
#####################################
header "Testing for missing dependencies"
# Files currently in the core + those provided in this ticket
ls *xml *txt |sort -u >/tmp/existing-files.txt

# Check which files are referenced from the xml files
cat schema*.xml solrconfig*.xml | sed -e '/<!--/,/-->/d' |egrep --color=none -o "[A-Z0-9a-z][A-Za-z0-9_-]*\.(txt|xml)" |fgrep -v "INFOSTREAM" |cut -f2 -d':' |sort -u >/tmp/referenced-files.txt

# Report which files **might** be missing (not guaranteed to catch all missing files!)
comm -23 /tmp/referenced-files.txt /tmp/existing-files.txt >$tmpout

if [ `grep -cv "ThisFileDoesNotExist-ItsJustAHack.txt" $tmpout` -gt 0 ]
then
  files=`cat $tmpout |tr '\012\015' ' '`
  errmsg "POSSIBLE missing required files have been detected in configuration: $files"
  pausemsg
else
  echo "OK! Couldn't detect references to missing files."
fi
echo ""

#####################################
# Create Solr core and test files.
#####################################
header "Test configuration changes in Local Solr"

solr_dir=`solrfolder 3`
if [ $solr_version -eq 4 ]
then
  solr_dir=`solrfolder 4`
fi

# Place config into Solr instance
echo "Putting configuration into solr local instance at $solr_dir."
cd $solr_dir/example
solrconf_folder=solr/conf
if [ $solr_version -eq 4 ]
then
  solrconf_folder=solr/collection1/conf
fi

if [ -d $solrconf_folder ]
then
  mv $solrconf_folder ${solrconf_folder}_last
fi
# Make extra sure there's nothing at solr/conf
rm ${solrconf_folder} 2>/dev/null
ln -s $origconf_dir ${solrconf_folder}

solrlog=$tmpdir/${core}-${date}-solr-startup.log
errlog=$tmpdir/${core}-${date}-solr-startup-errors.log
echo "Writing Solr log to $solrlog"
printf "Starting solr ${solr_full_version}..."
# Log Solr starting output
java -jar start.jar >$solrlog 2>&1 &
# Kill solr after max_time seconds maximum
background_pid=$!
echo -n "${COLOR_YELLOW} waiting..."
max_time=60
regex="Registered new searcher|java.net.BindException|java.text.ParseException|SolrDispatchFilter.init.. done"
for counter in `seq 1 $max_time`
do
  sleep 1
  if [ `tail -200 $solrlog |egrep -c "$regex"` -gt 0 ]
  then
    echo "done in $counter seconds!"
    sleep 1
    break
  fi
  echo -n '.'
done
if [ $counter -eq $max_time ]
then
  echo "${COLOR_RED}TIMEOUT at $counter seconds..."
  warnmsg "POSSIBLY the script needs to have more than $max_time seconds to let Solr start up (script detects that Solr finished startup based on the regex '$regex')"
  pausemsg
  exit 1
fi

echo "${COLOR_NONE}Stopping process $background_pid."
kill $background_pid

# Parse the startup log.
if [ $solr_version -eq 3 ]
then
  cat $solrlog |awk 'NR==1 { err=0; out=""; } /^'`date +%h`' [0-9]/ { if (err==1) print out; out=""; err=0; } /SEVERE|WARN|ERROR/ { err=1 } { out=out "\n" $0 }' >$errlog
else
  cat $solrlog |awk 'NR==1 { err=0; out=""; } /^[0-9][0-9]*  *\[/ { if (err==1) print out; out=""; err=0; } /SEVERE|WARN|ERROR/ { err=1 } { out=out "\n" $0 }' |grep -v "directory to add to classloader: ./conf/lib" >$errlog
fi

header "Results of Local Solr testing"

# Don't care about some warnings like:
#   "No queryConverter defined, using default converter"
#   "WARNING: Synonyms loaded with { ... snip ... } has empty rule set!
if [ `egrep -v "using default converter|has empty rule set|ThisFileDoesNotExist-ItsJustAHack.txt|Multiple default requestHandler registered" $errlog | egrep -c 'SEVERE|WARN|ERROR'` -gt 0 ]
then
  echo ""
  errmsg "There were Solr startup warnings/errors! Relevant log lines follow:"
  echo "${COLOR_RED}- - - - - - - - - - - - - - - - - - - - -"
  cat $errlog
  echo "- - - - - - - - - - - - - - - - - - - - -"
  echo "All errors above located at:"
  echo "  $errlog"
  echo "And the complete Solr startup log (errors + nonerrors) is at:"
  echo "  $solrlog"
  echo "Diff summary:"
  echo "  $diff_file"
  echo "${COLOR_NONE}- - - - - - - - - - - - - - - - - - - - -"


  if [ `egrep -c 'SEVERE|ERROR' $errlog` -gt 0 ]
  then
    header "PROBLEMS DETECTED: CUSTOMER INTERVENTION NEEDED:"
    cat <<EOF >$ticket_response_file
Hello,

Unfortunately, when testing the files you have submitted on this ticket, the Solr core ${core} (running Solr ${solr_full_version}) would not start up properly. Attached find Solr startup logs.

We ask you to:

* Review the attached Solr startup logs provided by our testing.
* Re-test your submissions on a local Solr instance (version ${solr_full_version}), making sure you:
  * 1) get the current configuration files from your Acquia-hosted index and install them onto your local Solr testing instance (read below on how to get these files)
  * 2) apply the changes you attached to this same ticket
* After you correct any errors, please re-attach every file changed between step 1 and 2 onto this ticket, confirming the Solr Index ID(s) or URL(s) where we should deploy the changes to.

Note that you can obtain the current Solr configuration files at any time via Drupal, using either of these methods:

* If using apachesolr.module: go to \`/admin/reports/apachesolr/\` and click on a server. Then, use the "Configuration Files" tab to access the Solr configuration files.
* If using search_api_solr.module: go to \`/admin/config/search/search_api\` and click on a server name. Then, use the "Files" tab to access the Solr configuration files.

If you require documentation on setting up a local Solr instance (version ${solr_full_version}) for testing, please see: https://support.acquia.com/hc/en-us/articles/360004423034-How-to-test-a-custom-Solr-schema-file-locally

EOF

    # Interactive/automatic ticket reply
    ticket_reply_interactive $zendesk_ticket $ticket_response_file $solrlog public

    echo "${COLOR_RED}Severe messages found. Exiting.${COLOR_NONE}"
    pausemsg
    exit 1
  else
    echo "${COLOR_YELLOW}Only warnings found... please check before continuing.${COLOR_NONE}"
    pausemsg
  fi
else
  echo "  ${COLOR_GREEN}No Solr startup errors found!${COLOR_NONE}"
  echo "  Find the complete Solr startup log at:"
  echo "    $solrlog"
fi

# Build summary file.
echo "Ticket z${zendesk_ticket} | "`whoami`" |" >$summary_file_with_ticket
cat $summary_file >>$summary_file_with_ticket

# If NO_DEPLOY, then stop here.
if [ "${NO_DEPLOY:-x}" -eq 1 ]
then
  warnmsg "--no-deploy argument given, stopping script."
  exit
fi


# Determine upload mode.
upload_mode="manual"
if [ `check_governor_access` -eq 1 ]
then
  upload_mode="auto"
fi

if [ "${upload_mode}" = "auto" ]
then
  header "Deploying files into ${core} index"
  deploy_files_into_governor ${core} $realfilestoupload_dir $summary_file_with_ticket
fi

if [ "${upload_mode}" = "manual" ]
then
  # Show success and ping core
  header "MANUAL STEP: Manually upload file to ${core} index"
  govurl=`asgetgovurl ${core}`
  cat <<EOF

  ${COLOR_YELLOW}1) If you have governor access, edit the core here:

    $govurl

  2) REMOVE these files (if they've been uploaded before):
  ${COLOR_GRAY}
  EOF
  awk '{print "  " $0 }' $tmpdir/overwritten-files-list.txt

  cat <<EOF
${COLOR_YELLOW}
3) UPLOAD all the file(s) from this folder:

  $realfilestoupload_dir

... and use this as the node revision message:
- - - - - - - - - - - - - - - - - - - - -${COLOR_GRAY}
EOF

  cat $summary_file_with_ticket
  # Also place this file into the clipboard
  file_to_clipboard $summary_file_with_ticket

  cat <<EOF
${COLOR_YELLOW}- - - - - - - - - - - - - - - - - - - - -

3) On the Governor: SAVE the node.

4) On this Terminal: watch the pinging below, ${COLOR_RED}make sure the core goes down and then comes back up!${COLOR_NONE}
${COLOR_NONE}
EOF
fi

# Do pinging
header "Waiting for Solr core to restart in master and slave"
if [ "${NO_PING:-x}" -eq 1 ]
then
  warnmsg "--no-ping argument given, skipping this check."
else
  aswaitforcycle $core
  if [ $? -eq 0 ]
  then
    echo "Pinging done!"
  else
    echo "${COLOR_RED}Pinging failed! You can use the below commands to attempt repair"
    cat $tmpout_governor |php -r '$result = json_decode(trim(stream_get_contents(STDIN)));
$core=$result->index_id;
$master=$result->master;
$slave=reset($result->slaves);
$user=$result->unix_username;

  echo <<<HEREDOC
# Fix master:
#   Copy this oneliner into your terminal.
ssh -F \$HOME/.ssh/ah_config {$master} "sudo -u {$user} bash -c \"cd && rake update_subscription_data && rake client_force_reload client={$core} && rake cron\""

# Fix slave:
#
# STEP 1) SSH IN with this command...
ssh -F \$HOME/.ssh/ah_config {$slave}

#
# STEP 2) ... Then copy-paste these into the commandline...
sudo su {$user}
cd && rake update_subscription_data && curl -sS "http://localhost:8081/solr/admin/cores?action=UNLOAD&core=boot-{$core}" && rake client_force_reload client={$core} && rake cron
HEREDOC;
'
    echo "${COLOR_NONE}"
    pausemsg
  fi
fi

# Output canned response
header "LAST STEP: Send response and file(s) via ticket $zendesk_ticket"
# Build ticket response
cat <<EOF >$ticket_response_file
Hello,

Configuration changes have been posted into the Solr index ${core}. You may have to wait a few minutes before they are fully processed and deployed into the Solr index's active configuration.

\`\`\`
EOF

cat $summary_file >>$ticket_response_file
cat <<EOF >>$ticket_response_file
\`\`\`

Attached find a \`.diff\` file showing changes between the previous and current Solr configuration files.

**In some cases, you will need to reindex your site**. If applicable, you should use the same procedures as those you followed with your prior testing of these files before submitting them to Acquia.

Note that you can obtain the current Solr configuration files at any time via Drupal, using either of these methods:

* If using apachesolr.module: go to \`/admin/reports/apachesolr/\` and click on a server. Then, use the "Configuration Files" tab to access the Solr configuration files.
* If using search_api_solr.module: go to \`/admin/config/search/search_api\` and click on a server name. Then, use the "Files" tab to access the Solr configuration files.

EOF

ticket_reply_interactive $zendesk_ticket $ticket_response_file $diff_file public

echo "NOTE: If you've finished ALL requested changes,"
echo "      you should go to the ticket and mark it 'Solved'."
exit 0
