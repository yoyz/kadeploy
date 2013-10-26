package libkadeploy2::kanodes;

use Getopt::Long;
use libkadeploy2::deploy_iolib;
use libkadeploy2::conflib;
use libkadeploy2::nodesfile;
use libkadeploy2::disk;
use libkadeploy2::node;
use libkadeploy2::message;

use strict;
use warnings;

sub loadnodesfile($);
sub loadpartitionfile($);
sub updatedeployedtable();
sub usage();
sub listnodes();
sub delpartitiontable();
sub listpartition($);
sub nodetoadd($);
sub nodetodel($);

my $kadeployconfdir="/etc/kadeploy";
my $nodesdir="$kadeployconfdir/nodes";
my $defaultpartitionfile=$kadeployconfdir."/clusterpartition.conf";
my $partitionfilecmd="";

my @hostlist;	     
my $help;
my $listnode;
my $listpartition;
my $iwanthelp=1;
my $retcode;
my $add;
my $del;
my $message=libkadeploy2::message::new();
my $disk_id;
my @host_id_list = ();
my @part_env_id_list = ();
my $ok=1;
my $nodename;

################################################################################

sub run()
{
    if ($add)
    {	
	$retcode=0;
	if (@hostlist)
	{
	    foreach $nodename (@hostlist)
	    {
		if (nodetoadd($nodename)==0) { $retcode=1; }
	    }
	}
	else
	{
	    $message->missing_node_cmdline(2);
	    $retcode=1;
	}
	return $retcode;
    }
    
    if ($del)
    {
	$retcode=0;
	if (@hostlist)
	{
	    
	    foreach $nodename (@hostlist)
	    {	    
		if (nodetodel($nodename)==0)
		{
		    $retcode=1;
		}
	    }
	}
	else
	{
	    $message->missing_node_cmdline(2);
	    $retcode=1;
	}
	return $retcode;
    }
    
    if ($listnode)
    {
	$retcode=0;
	listnodes();
	return $retcode;
    }
    
    if ($listpartition)
    {
	$retcode=0;
	if (@hostlist)
	{
	    foreach $nodename (@hostlist)
	    {
		listpartition($nodename);
	    }
	}
	else
	{
	    $message->missing_node_cmdline(2);
	    $retcode=1;
	}
	return $retcode;
    }

    if ($iwanthelp)
    {
	$retcode=0;
	$message->kanodes_help();
	return $retcode;
    }    
}

sub get_options_cmdline()
{
    GetOptions('m=s'             => \@hostlist,
	       'h!'              => \$help,
	       'add!'            => \$add,
	       'del!'            => \$del,
	       'listnode!'       => \$listnode,
	       'listpartition!'  => \$listpartition,
	       'partitionfile=s' => \$partitionfilecmd,
	       );
}

sub check_options()
{
    if ($help) { $message->kanodes_help(); return 0; }
}


sub nodeexist($)
{
    my $nodename=shift;
    my $ok=0;
    my $db;

    $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    if ($db->node_name_exist($nodename)) {$ok=1;}
    else {$ok=0;}
    $db->disconnect();
    return $ok;
}

sub nodetoadd($)
{
    my $nodename=shift;
    $iwanthelp=0;
    my $disk;
    my $node;
    my $base;
    my $i;
    my $nodenamedir="$nodesdir/$nodename";
    my $nodefile="$nodenamedir/net";
    my $diskfileprefix="$nodenamedir/disk";
    my $partitionfileprefix="$nodenamedir/partition.conf";
    my $partitionfile="";
    my $errpartitionfile="";
    my $diskfile;
    my $ok=1;
    my $diskid;
    my $db;


    if (! -d $nodenamedir)   { $message->dirnotfound(2,$nodenamedir); return 0; }
    if (! -e $nodefile)      { $message->filenotfound(2,$nodefile);   return 0; }


    $node=libkadeploy2::node::new();
    $disk=libkadeploy2::disk::new();

    $message->loadingfile(0,$nodefile);

    if ($node->loadfile($nodefile))
    { 	
	$message->loadingfileDone(0,$nodefile);
	$node->addtodb();     
    }
    else
    { 
	$message->loadingfilefailed(2,$nodefile);
	$ok=0; 
    }      
    
    for ($i=1;$i<5;$i++)
    {
	$diskfile="$diskfileprefix-$i";
	$partitionfile="$partitionfileprefix-$i";
	$message->statfile(0,$diskfile);
	if (! -e $diskfile && $i==1) 
	{ 
	    $message->filenotfound(2,$diskfile);
	    return 0; 
	}
	if (-e $diskfile)
	{
	    $message->message(-1,"Checking $diskfile");
	    if (! $disk->loaddisksettingfile($diskfile)) 
	    { $message->message(2,"with diskfile $diskfile"); return 0; }

	    if (-e $partitionfilecmd)
	    {
		if (! $disk->loadpartitionfile($partitionfilecmd)) 
		{ $errpartitionfile=$partitionfilecmd; $ok=0; }
	    }
	    elsif (-e "$partitionfileprefix-$i")
	    {
		if (! $disk->loadpartitionfile($partitionfile)) 
		{ $errpartitionfile=$partitionfile; $ok=0; }
	    }
	    elsif (-e $defaultpartitionfile)
	    {
		if (! $disk->loadpartitionfile($defaultpartitionfile)) 
		{ $errpartitionfile=$defaultpartitionfile; $ok=0; }
	    }
	    if (! $ok) { $message->message(2,"with $partitionfile $errpartitionfile"); return $ok; }

	    $db = libkadeploy2::deploy_iolib::new();
	    $db->connect();		

	    my $nodeid=$db->node_name_to_id($nodename);
	    my $diskid=$db->get_diskid_from_nodeid_disknumber($nodeid,$i);
	    if ($nodeid && $diskid)
	    {
		$message->message(0,"delete partition from $nodename");
		$db->del_partition_from_diskid($diskid);
		$ok=1;
	    }
	    if (! $disk->addtodb($nodename,$i)) { $ok=0;}
	    $db->disconnect();
	}
    }
    

    if ($ok)
    {
	updatedeployedtable(); 
	return $ok;
    }
    else
    {
	$message->message(2,"Check your configuration files...");
	return $ok;
    }

}



sub nodetodel($)
{
    my $nodename=shift;
    my $iwanthelp=0;
    my $db;
    my $diskid;
    my $nodeid;
    my $i;
    my $ok=0;

    $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    if ($db->node_name_to_id($nodename)==0)
    {
	$message->missing_node_db(2,$nodename);
	exit 1;
    }
    else
    {
	$nodeid=$db->node_name_to_id($nodename);
	for ($i=1;$i<5;$i++)
	{
	    $diskid=$db->get_diskid_from_nodeid_disknumber($nodeid,$i);
	    if ($diskid)
	    {
		$message->message(0,"delete partition from $nodename");
		$db->del_partition_from_diskid($diskid);
		$message->message(0,"delete disk from $nodename");
		$db->del_disk_from_id($diskid);
		$ok=1;
	    }
	    else
	    {
		$message->missing_disk_db(1,$nodename);
	    }
	}
	$message->message(0,"delete host $nodename");
	$db->del_node($nodename);
    }
    $db->disconnect();    
    return $ok;
}

sub listpartition($)
{
    my $nodename=shift;
    my $partsize;
    my $partnumber=1;
    my $i;
    my $db = libkadeploy2::deploy_iolib::new();
    $db->connect();
    my $disk = libkadeploy2::disk::new();
    for ($i=1;$i<5;$i++)
    {
	if ($disk->get_fromdb($nodename,$i))
	{
	    print "#disk=$i\n";
	    $disk->print();
	    print "\n";
	    $disk=libkadeploy2::disk::new();
	}

    }
    $db->disconnect();
}

sub listnodes()
{
    my @nodelist;
    my $node;
    my $db = libkadeploy2::deploy_iolib::new();
    $db->connect();
    @nodelist=$db->list_node();
    print STDERR "node list\n";
    print STDERR "---------\n";
    foreach $node (@nodelist)
    {
	print "$node\n";
    }
    $db->disconnect();					  
}




sub updatedeployedtable()
{
    my $db = libkadeploy2::deploy_iolib::new();
    $db->connect();
    foreach my $host (@host_id_list)
    {
	foreach my $part_env (@part_env_id_list)
	{
	    $db->add_deploy(\$part_env,$disk_id,$host);
	  }
    }
    
    $db->disconnect();    
}


1;
