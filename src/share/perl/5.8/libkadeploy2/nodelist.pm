package libkadeploy2::nodelist;

use strict;
use warnings;
use libkadeploy2::node;
use libkadeploy2::message;
use IO::Socket;


my $message=libkadeploy2::message::new();
my $nodeconfdir="/etc/kadeploy/nodes/";

sub new()
{
    my $self;
    my @nodelist=();
    my $refnodelist=\@nodelist;
    $self =
    {
	nodelist => $refnodelist,
    };
    bless $self;
    return $self;
}

#params : node object
sub add($)
{
    my $self=shift;
    my $node=shift;
    my $refnodelist=$self->{nodelist};
    my @nodelist=@$refnodelist;
    @nodelist=(@nodelist,$node);
    $refnodelist=\@nodelist;
    $self->{nodelist}=$refnodelist;
}

#params : node property (name or ip)
sub del($)
{
    my $self=shift;
    my $nodeproperty=shift;
    my @newlist=();
    my @hostlist;
    my $hostlistref;
    my $node;
    my $retcode=0;
    $hostlistref=$self->{nodelist};
    @hostlist=@$hostlistref;
    
    foreach $node (@hostlist)
    {
	if ($node->get_name() eq $nodeproperty ||
	    $node->get_ip()   eq $nodeproperty
	    )
	{
	    $retcode=1;
	}
	else
	{
	    @newlist=(@newlist,$node);
	}
    }
    $hostlistref=\@newlist;
    $self->{nodelist}=$hostlistref;
    return $retcode;
}

sub get_node($)
{
    my $self=shift;
    my $number=shift;
    my $refnodelist=$self->{nodelist};
    my @nodelist=@$refnodelist;
    return $nodelist[$number];
}

sub get_nodes()
{
    my $self=shift;
    my $refnodelist=$self->{nodelist};
    return $refnodelist;
}


sub get_numberofnode()
{
    my $self=shift;
    my $number=shift;
    my $refnodelist=$self->{nodelist};
    my @nodelist=@$refnodelist;
    return $#nodelist;
}

sub get_ip_list()
{
    my $self=shift;
    my @ip_list;
    my $ref_ip_list;
    my $ip;
    my $refnodelist=$self->{nodelist};
    my @nodelist=@$refnodelist;
    my $node;
    foreach $node (@nodelist)
    {
	@ip_list=(@ip_list,$node->get_ip());
    }
    $ref_ip_list=\@ip_list;
    return $ref_ip_list;
}

sub get_cmdline()
{
    my $self=shift;
    my $node;
    my $refnodelist;
    my @node_list;
    my $nodeshell;

    $refnodelist=$self->get_nodes();
    @node_list=@$refnodelist;

    foreach $node (@node_list)
    {
	$nodeshell.=" -m ".$node->get_name();
    }
    return $nodeshell;
}

sub get_str()
{
    my $self=shift;
    my $node;
    my $refnodelist;
    my @node_list;
    my $nodesstr;

    $refnodelist=$self->get_nodes();
    @node_list=@$refnodelist;

    foreach $node (@node_list)
    {
	if (! $nodesstr) { $nodesstr=$node->get_name(); }
	else { 	$nodesstr.=" ".$node->get_name(); }
    }
    return $nodesstr;
}


sub print()
{
    my $self=shift;
    my $node;
    my $refnodelist=$self->{nodelist};
    my @nodelist=@$refnodelist;
    foreach $node (@nodelist)
    {
	$node->print();
    }    
}

sub loadfile($) 
{
    my $self=shift;
    my $nodefile=shift;
    my $message=libkadeploy2::message::new();
    my $nodenetfile;
    my $line;
    my $node;
    my $ok=0;
    open(NODEFILE,"$nodefile") or die "Can't open $nodefile\n";
    foreach $line (<NODEFILE>)
    {
	chomp($line);
	if ($line)
	{
	    $nodenetfile=$nodeconfdir."/".$line."/net";
	    if (-e $nodenetfile)
	    {
		$node=libkadeploy2::node::new();
		if ($node->loadfile($nodenetfile))
		{
		    $self->add($node);
		    $ok=1;
		}
	    }
	    else
	    {
		$message->filenotfound(2,$nodenetfile);
		$ok=0;
		return $ok;
	    }
	}
    }
    close(NODEFILE);
    return $ok;
}

sub loadlist($)
{
    my $self=shift;
    my $refnodelist=shift;
    my @nodelist=@$refnodelist;
    my $nodeelem;
    my $nodeobject;
    my $nodename;
    my $nodeip;
    my $tmp;
    my $ok=1;
    my $AF_INET = 2;
    my $sockaddr = 'S n a4 x8';
    my $thisaddr;
    
    foreach $nodeelem (@nodelist)
    {
	$nodeobject=libkadeploy2::node::new();
	if ($nodeobject->getfromdb($nodeelem))
	{
	    $self->add($nodeobject);
	}
	else
	{
	    ($nodename,$tmp,$tmp,$tmp,$thisaddr)=gethostbyname($nodeelem);
	    if ($nodename)
	    {
		$nodeip = inet_ntoa((gethostbyname($nodename))[4]);
	    }
	    if ($nodename && $nodeip)
	    {
		$nodeobject->set_name($nodename);
		$nodeobject->set_ip($nodeip);
		$nodeobject->set_mac("00:11:22:33:44:55");
		$self->add($nodeobject);
	    }
	    else
	    {
		$message->message(2,"node $nodeelem doesn't exist in DB (nodelist::loadlist)");
		$ok=0;
	    }
	}
    }
    return $ok;
}

1;
