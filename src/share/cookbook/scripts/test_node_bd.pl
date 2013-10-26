#!/usr/bin/perl

use node_bd;
use KaLib::Nodes;

use strict;

my $node1 =  nodebd->new("idpot7");
$node1->set_values();

my $node2 =  nodebd->new("idpot4");
$node2->set_values();

my $node3 =  nodebd->new("idpot5");
$node3->set_values();

my $node_set = Nodes->new();

$node_set->add($node1);
$node_set->add($node2);
$node_set->add($node3);

$node_set->check();

$node1->set_state(1);

print @{$node_set->{nodesReady}};
