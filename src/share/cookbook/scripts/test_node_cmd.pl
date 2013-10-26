#!/usr/bin/perl

use NodeCmd;
use KaLib::Nodes;

use strict;

my $environment = "deployment";


#
# Declare Node instances
#
my $node1 =  NodeCmd->new("idpot7");
$node1->set_values();

my $node2 =  NodeCmd->new("idpot4");
$node2->set_values();

my $node3 =  NodeCmd->new("idpot5");
$node3->set_values();

my $node4 =  NodeCmd->new("idpot1");
$node4->set_values();

my $node5 =  NodeCmd->new("idpot8");
$node5->set_values();


#
# Declare Nodes sets
#
# all nodes
my $node_set_all = Nodes->new($environment);

# first part
my $node_set_1 = Nodes->new($environment);

# the rest
my $node_set_2 = Nodes->new($environment);


#
# fill these
#
$node_set_all->add($node1);
$node_set_all->add($node2);
$node_set_all->add($node3);
$node_set_all->add($node4);
$node_set_all->add($node5);

$node_set_1->add($node1);
$node_set_1->add($node3);

$node_set_2->add($node2);
$node_set_2->add($node3);
$node_set_2->add($node4);


#
# Let's manipulate them
#

$node_set_all->check();

if($node_set_all->ready()) {
    print "all nodes are ready\n";
}
else {
    print "missing some...\n";
}

$node_set_1->runRemoteCommand("\"echo \"coucou\" > /mnt/rambin/test\"");

print %{$node_set_1->{nodesReady}} . "\n";

$node_set_2->runRemoteCommand("echo \"idpot7\"");

$node_set_all->runRemoteCommand("\" cat /mnt/rambin/test \"");


print "Nodes not reached:";
print @{$node_set_2->{nodesNotReached}};
