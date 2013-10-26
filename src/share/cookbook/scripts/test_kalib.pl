#! /usr/bin/perl

use NodeCmd;
use KaLib::Nodes;

use strict;


#
# Declare Node instances
#

my $node1 =  NodeCmd->new("idpot3");
$node1->set_values();


#my $node_set_deployment = Nodes->new("deployment");
#if(!$node_set_deployment) {die("problem occured!");}
#$node_set_deployment->add($node1);


my $node_set_production = Nodes->new("production");
if(!$node_set_production) {die("problem occured!");}
$node_set_production->add($node1);



$node_set_production->check();


if($node_set_production->ready()) {
    print "all nodes are ready\n";
}
else {
    print "missing some...\n";
}

$node_set_production->runReportedRemoteCommand("echo coucou");
