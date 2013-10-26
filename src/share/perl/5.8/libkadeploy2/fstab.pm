package libkadeploy2::fstab;

use strict;
use warnings;
use libkadeploy2::disk;
use libkadeploy2::device;
use libkadeploy2::message;

my $message=libkadeploy2::message::new();

sub new()
{
    my $self=
    {
	disk_1 => "",
	disk_2 => "",
	disk_3 => "",
	disk_4 => "",
	bootdisknumber => 0,
	bootpartnumber => 0,
    };
    bless $self;
    return $self;
}

sub set_bootdisknumber($) { my $self=shift; my $disknumber=shift; $self->{disknumber}=$disknumber; }
sub set_bootpartnumber($) { my $self=shift; my $partnumber=shift; $self->{partnumber}=$partnumber; }

sub add_disk($$)      
{ 
    my $self=shift; 
    my $disknumber=shift; 
    my $disk=shift; 
    $self->{"disk_$disknumber"}=$disk;
}

sub print()
{
    my $self=shift;
    my $disknumber=$self->{disknumber};
    my $partnumber=$self->{partnumber};
    my $ret=0;
    $ret=$self->get();
    if ($ret) { print $ret; return 1; }
    else { return $ret; }
}


sub check($)
{
    my $self=shift;
    my $disknumber=$self->{disknumber};
    my $partnumber=$self->{partnumber};
    my $disk=$self->{"disk_$disknumber"};
    my $diskinterface=$disk->get_interface();
    my $linuxdevice;
    my $ok=1;


    for ( my $i=1 ; $i< $disk->get_numberofpartition()+1; $i++)
    {
	if ($disk->get_frompartition($i,"label"))
	{
	    if ($i == $partnumber)
	    {
		if (!($disk->get_frompartition($i,"fs") =~  /ext2|ext3/))
		{
		    $message->message(2,"Bad fs ".$disk->get_frompartition($i,"fs")." for root fs");
		    $ok=0;
		}
	    }
	}
    }
    return $ok;
}

sub get($)
{
    my $self=shift;
    my $ostype=shift;
    my $disknumber=$self->{disknumber};
    my $partnumber=$self->{partnumber};   
    my $disk=$self->{"disk_$disknumber"};
    my $diskinterface=$disk->get_interface();
    my $ret=1;
    if ($self->check())
    {
	if ($ostype && $ostype eq "linux")
	{ $ret=$self->get_linux(); }
    }
    else { $ret=0; }
    return $ret;
}


sub get_linux()
{
    my $self=shift;
    my $disknumber=$self->{disknumber};
    my $partnumber=$self->{partnumber};

    my $disk=$self->{"disk_$disknumber"};
    my $linuxdevice;
    my $diskinterface=$disk->get_interface();
    my $fstab="";
    for ( my $i=1 ; $i< $disk->get_numberofpartition()+1; $i++)
    {
	$linuxdevice=libkadeploy2::device::new($diskinterface,$disknumber,$i); 	
	if ($disk->get_frompartition($i,"label"))
	{
	    if ($i eq $partnumber)
	    {
		if (
		    (
		     $disk->get_frompartition($i,"label") eq "unknow" ||
		     $disk->get_frompartition($i,"label") eq "/"
		     ) &&		    		    
		    $disk->get_frompartition($i,"fs") =~  /ext2|ext3/
		    )		    		    
		{
		    $fstab.="/dev/".$linuxdevice->get("linux")." ".
			"/ ".
			$disk->get_frompartition($i,"fs")." ".
			" defaults 1 1 \n";
		}
		else 
		{
		    $message->message(2,"Bad fs or label for root filesystem".
				      " fs=".$disk->get_frompartition($i,"fs").
				      " label=".$disk->get_frompartition($i,"label").
				      "");
		    exit 1;
		}

	    }
	    elsif ($disk->get_frompartition($i,"label") eq "swap")
	    {
		$fstab.="/dev/".$linuxdevice->get("linux")." ".
		    "none ".
		    $disk->get_frompartition($i,"fs")." ".
		    " defaults\n";
	    }
	    elsif (!($disk->get_frompartition($i,"label") eq "unknow"))
	    {
		$fstab.="/dev/".$linuxdevice->get("linux")." ".
		    $disk->get_frompartition($i,"label")." ".
		    $disk->get_frompartition($i,"fs")." ".
		    " defaults 1 1 \n";
	    }
	    else
	    {
		$message->message(-1,"not a linux partition part=$i");
	    }
		   
	}
    }
    $fstab.=$self->get_otherlinux();
    return $fstab;
}

sub get_otherlinux()
{
    my $self=shift;
    my $otherlinux;
    $otherlinux="proc /proc proc defaults 0 0\n";
    return $otherlinux;
}

1;
