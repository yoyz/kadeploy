#! /usr/bin/perl

BEGIN{
    unshift(@INC, ".", "..");
}

use strict;

use lib::node_bd;
use lib::nodes;
use lib::deploy_iolib;

my $base = deploy_iolib::connect();
deploy_iolib::add_node_to_deployment($base,"idpot2","101","debian","hda","1");
deploy_iolib::disconnect($base);

exit 0;

#my $is_free = deploy_iolib::is_node_free($base,1,96);
#if($is_free){
#    print("Node is free!\n");
#}else{
#    print("Node is not free...\n");
#}

#deploy_iolib::disconnect($base);
#exit 0;

#my $tmp = deploy_iolib::node_name_to_id($base,"idpot37");
#print "ID = $tmp\n";

# new deployment creation
my $deployment = deploy_iolib::prepare_deployment($base);

# manual partition selection
my %ip_addr = ("192.168.10.7" => ["1","7"], "192.168.10.4" => ["1","7"], "192.168.10.1" => ["1","7"]);

# begin deployment (updates deployed table)
my $environment = deploy_iolib::env_name_to_last_ver_id($base,"debian");

# add nodes to system structures
my $node1 =  node_bd->new_db("idpot7", 97, "debian", 7);
$node1->set_values();

my $node2 =  node_bd->new_db("idpot4", 97, "debian", 7);
$node2->set_values();

my $node3 =  node_bd->new_db("idpot1", 97, "debian", 7);
$node3->set_values();


my $node_set = Nodes->new();
$node_set->add($node1);
$node_set->add($node2);
$node_set->add($node3);

$node_set->check();





if($node_set->ready()) {
    print "all nodes are ready\n";
}
else {
    print "missing some...\n";
}



# runs the deployment (changes state to run)
deploy_iolib::run_deployment($base,$deployment);

# mount rambin to perform benchs,...
$node_set->runCommand(" cat /home/nis/jleduc/Boulot/rambin/rambin.tgz |", "\"tar zxC /mnt/rambin \"");
$node_set->runRemoteCommand("\" /rambin/init.ash \"");
$node_set->runRemoteCommand("\" mkfs -t ext2 /dev/hda7 \"");
$node_set->runRemoteCommand("\" mount /dev/hda7 /mnt/dest \"");
$node_set->runCommand(" cat /home/nis/jleduc/ImagesDistrib/image_Debian_current.tgz |", "\"tar zxC /mnt/dest \"");

# error if a node failed then checks which node has failed
# and turns the others to 'deployed' state
deploy_iolib::end_deployment($base,$deployment);

deploy_iolib::disconnect($base);
