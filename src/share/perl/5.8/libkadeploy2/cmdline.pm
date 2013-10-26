package libkadeploy2::cmdline;
use libkadeploy2::message;
use libkadeploy2::nodelist;
use strict;
use warnings;

sub loadhostfileifexist($);
sub loadhostcmdlineifexist($);


sub loadhostfileifexist($)
{
    my $hostfile=shift;
    my $nodelist;
    my $message=libkadeploy2::message::new();

    if ($hostfile &&
	-f $hostfile
	)
    {
	$nodelist=libkadeploy2::nodelist::new();
	if (! $nodelist->loadfile($hostfile)) 
	{ 
	    $message->loadingfilefailed(2,$hostfile);
	    exit 1;
	}
    }
    return $nodelist;
}

sub loadhostcmdlineifexist($)
{
    my $refhostlist=shift;
    my @hostlist=@$refhostlist;
    my $message=libkadeploy2::message::new();
    my $nodelist;

    if (@hostlist)
    {
	$nodelist=libkadeploy2::nodelist::new();
	$nodelist->loadlist(\@hostlist);
    }
    return $nodelist;
}


sub get_nodes_cmdline($)
{
    my $nodelist=shift;
    my $strret;
    my $ref_node_list;
    my @node_list;

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;
    foreach my $node (@node_list)
    {
	$strret.=" -m ".$node->get_name();
    }
    if (! $strret) { print "ERROR : get_nodes_cmdline\n"; exit 1; }
    return $strret
}

1;
