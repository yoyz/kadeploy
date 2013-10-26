package libkadeploy2::disks;
use strict;
use warnings;

use libkadeploy2::disk;
use libkadeploy2::nodelist;
use libkadeploy2::message;

sub check_disk_type($);
sub get_disk_type($);

my $message=libkadeploy2::message::new();

sub new($)
{
    my $nodelist=shift;
    my $self;
    $self=
    {
	nodelist => $nodelist,
    };
    bless $self;
    return $self;
}

sub check_disk_type($) 
{
    my $self=shift;
    my $disknumber=shift;
    my $ref_node_list;
    my @node_list;
    my $node;
    my $nodename;
    my $disktype;
    my $disk;
    my $i;
    my $ok=1;
    my $nodelist;

    $nodelist=$self->{nodelist};

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    $i=0;
    foreach $node (@node_list)
    {
	$nodename=$node->get_name();
	$disk=libkadeploy2::disk::new();
	$disk->get_fromdb($nodename,$disknumber);
	if ($i==0)
	{
	    $disktype=$disk->get_interface();
	}
	else
	{
	    if (! ($disktype eq $disk->get_interface()))
	    { $message->message(2,"Error wrong interface disk (disks.pm)"); $ok=0; }
	}
    }
    return $ok;
}

sub get_disk_type($)
{
    my $self=shift;
    my $disknumber=shift;
    my $ref_node_list;
    my @node_list;
    my $node;
    my $nodename;    
    my $disktype;
    my $disk;
    my $i;
    my $nodelist;
    my $ok=1;

    $nodelist=$self->{nodelist};

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;
    
    $node=$node_list[0];
    $nodename=$node->get_name();
    $disk=libkadeploy2::disk::new();
    $disk->get_fromdb($nodename,$disknumber);
    $disktype=$disk->get_interface();   
    return $disktype;
}

1;
