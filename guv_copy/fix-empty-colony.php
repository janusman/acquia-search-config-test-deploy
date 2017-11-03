<?php

function _guv_copy_add_revision_to_node_object(&$node, $message) {
  // Add log line
  $node->revision = 1;
  $node->log = $message;
}

function _guv_copy_get_nids_from_core_id($core_id) {
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

function unpublish($nid, $revision_msg) {
  $node = node_load($nid, NULL, TRUE);
  $node->status = 0;
  _guv_copy_add_revision_to_node_object($node, $revision_msg);
  node_save($node);
}

function publish($nid, $revision_msg) {
  $node = node_load($nid, NULL, TRUE);
  $node->status = 1;
  _guv_copy_add_revision_to_node_object($node, $revision_msg);
  node_save($node);
}

function do_change($nid, $revision_msg) {
  $node = node_load($nid, NULL, TRUE);
  _guv_copy_add_revision_to_node_object($node, $revision_msg);
  if (!isset($node->field_colony["und"][0]["nid"])) {
	$node->field_colony = array(
	  "und" => array(
		0 => array (
		  "nid" => 79986,
		  "uuid" => "08b43509-ff7b-65f4-9dc6-4df5791930fd",
		),
	  ),
	);
	$node->field_farm = array(
	  "und" => array(
		0 => array (
		  "nid" => 79991,
		  "uuid" => "e14c9806-6fab-6214-45c4-93cba46ecf99",
		),
	  ),
	);
	node_save($node);
  }
}

$cores = "DKRT-108096.cit.beMP,DKRT-108096.cit.bePP,DKRT-108096.dev.beMP,DKRT-108096.dev.bePP,DKRT-108096.prod.beMP,DKRT-108096.prod.bePP,DKRT-108096.sit.beMP,DKRT-108096.sit.bePP,DKRT-108096.test.beMP,DKRT-108096.test.bePP,DKRT-108096.cit.nlMP,DKRT-108096.cit.nlPP,DKRT-108096.dev.nlMP,DKRT-108096.dev.nlPP,DKRT-108096.prod.nlMP,DKRT-108096.prod.nlPP,DKRT-108096.sit.nlMP,DKRT-108096.sit.nlPP,DKRT-108096.test.nlMP,DKRT-108096.test.nlPP";
foreach (explode(",", $cores) as $core_id) {
  echo "Processing core $core_id ...";
  $revision_msg = "AS-2248 fixing colony/farm";
  $source_nids = _guv_copy_get_nids_from_core_id($core_id);
  $nid = $source_nids[0];
  echo " node nid=$nid ...";
  $node = node_load($nid, NULL, TRUE);
  if (isset($node->field_colony["und"][0]["nid"])) {
  	echo " colony already set! SKIPPING\n";
  	continue;
  }
  unpublish($nid, $revision_msg);
  do_change($nid, $revision_msg);
  publish($nid, $revision_msg);
  echo " saved!\n";
}
