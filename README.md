## Acquia Search testing and deployment script

This script allows you to process requests to deploy custom Solr configuration
by first testing the configuration on a local Solr instance, and providing results.

This repo consists of 2 tools:

* `parse-solr-config-ticket.sh`: Helper script that fetches and parses a Zendesk ticket:
  * Downloads any attached files to a folder.
  * Scans ticket text for core IDs, and creates a mini-script that includes all the cores. (Assumes the same files go into all mentioned cores)
* `check-solr-config.sh`: Main script that does actual testing/deployment of config files into Solr.

Run each script for more help :)
